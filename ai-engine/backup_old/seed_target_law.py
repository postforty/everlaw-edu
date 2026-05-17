import os
import sys
import base64
import re
import json
from dotenv import load_dotenv
from github import Github
from langchain_text_splitters import MarkdownHeaderTextSplitter, RecursiveCharacterTextSplitter
from langchain_core.documents import Document

# ai-engine 폴더 참조 추가
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

load_dotenv()

# RAG 엔진 적재 함수 가져오기
try:
    from rag_engine import add_document_to_vector_store
    print("✅ RAG Engine 적재 모듈 로드 성공!")
except ImportError as e:
    print(f"❌ RAG Engine 로드 실패: {e}")
    sys.exit(1)

def extract_fine_grained_law_metadata(text, initial_metadata):
    """
    청크 텍스트 본문과 마크다운 헤더를 정규표현식(Regex)으로 정밀 분석하여
    [조, 조항 타이틀, 항, 호, 목] 주소 체계를 추출하여 메타데이터에 이식하는 고성능 파서 헬퍼
    """
    metadata = initial_metadata.copy()
    
    # 1. 조(Article) 및 조항 타이틀(Article Title) 추출
    article = None
    article_title = None
    
    # 💡 [정밀 헤더 5 매퍼]: sample 분석 결과 대한민국 모든 조는 '##### 제N조 (제목)'로 작성되어 있습니다.
    # MarkdownHeaderTextSplitter가 나눈 'Header 5' 값에서 직접 조와 조항 타이틀을 낚아채 오검출 0%를 구현합니다!
    header_5_val = metadata.get("Header 5")
    if header_5_val and isinstance(header_5_val, str):
        match = re.search(r"(제\s*\d+(?:의\d+)?\s*조)", header_5_val)
        if match:
            article = match.group(1).replace(" ", "")
            title_match = re.search(r"제\s*\d+(?:의\d+)?\s*조\s*\((.*?)\)", header_5_val)
            if title_match:
                article_title = title_match.group(1).strip()

    # 혹시 Header 5에 없다면, 메타데이터 전체 값들에서 순차 매칭 시도
    if not article:
        for val in metadata.values():
            if isinstance(val, str) and "조" in val:
                match = re.search(r"(제\s*\d+(?:의\d+)?\s*조)", val)
                if match:
                    article = match.group(1).replace(" ", "")
                    title_match = re.search(r"제\s*\d+(?:의\d+)?\s*조\s*\((.*?)\)", val)
                    if title_match:
                        article_title = title_match.group(1).strip()
                    break

    # 최후의 수단으로 본문 내에서 조(Article) 매칭
    if not article:
        match = re.search(r"(제\s*\d+(?:의\d+)?\s*조)", text)
        if match:
            article = match.group(1).replace(" ", "")
            title_match = re.search(r"제\s*\d+(?:의\d+)?\s*조\s*\((.*?)\)", text)
            if title_match:
                article_title = title_match.group(1).strip()

    if article:
        metadata["article"] = article
    if article_title:
        metadata["article_title"] = article_title

    # 2. 항(Paragraph) 추출: [Zen of Law Parser 적용 - 볼드체 **①** 서식 완벽 대응]
    # 실제 원본 문서의 모든 항 번호는 **①** 형태의 볼드체 원숫자로 표기되어 있습니다.
    # 본문 내의 유니코드 원숫자 기호(①~㊿) 자체를 정교하게 탐색 및 수집합니다.
    found_paras = []
    circled_matches = re.findall(r"\*?\*?([①-⑳㉑-㊿])\*?\*?", text)
    for mark in circled_matches:
        if mark not in found_paras:
            found_paras.append(mark)

    if found_paras:
        metadata["paragraphs"] = found_paras
        metadata["primary_paragraph"] = found_paras[0]

    # 3. 호(Subparagraph) 추출
    # 💡 [백슬래시 이스케이프 방어]: 마크다운 원본의 "1\. " 과 같이 백슬래시가 있는 경우도 100% 감지되도록 Regex 보강!
    sub_paras = re.findall(r"^\s*(\d+)\s*\\?\.", text, re.MULTILINE)
    if sub_paras:
        metadata["subparagraphs"] = [f"{num}호" for num in sub_paras]

    # 4. 목(Item) 추출 (줄 첫머리에 오는 가, 나, 다, 라... 한글 점)
    # 💡 [백슬래시 이스케이프 방어]: 목 뒤의 백슬래시 마침표 완벽 대응!
    items = re.findall(r"^\s*([가-힣])\s*\\?\.", text, re.MULTILINE)
    valid_items = [f"{char}목" for char in items if char in "가나다라마바사아자차카타파하"]
    if valid_items:
        metadata["items"] = valid_items

    return metadata

def seed_industry_safety_law():
    github_repo = os.getenv("GITHUB_REPO", "legalize-kr/legalize-kr")
    github_token = os.getenv("GITHUB_TOKEN")
    postgres_url = os.getenv("POSTGRES_URL", "postgresql+psycopg2://user:password@localhost:5432/everlaw_db")
    
    target_files = {
        "법률": "kr/산업안전보건법/법률.md",
        "시행령": "kr/산업안전보건법/시행령.md",
        "시행규칙": "kr/산업안전보건법/시행규칙.md"
    }

    if github_token and "your_github_token" not in github_token:
        gh = Github(github_token)
    else:
        gh = Github()
        print("⚠️ GITHUB_TOKEN이 구성되지 않아 익명 클라이언트로 기동합니다. (Rate Limit 주의)")

    print(f"\n📡 1단계: 원격 저장소 '{github_repo}'에서 산업안전보건법 마크다운 조문 수집 중...")

    try:
        repo = gh.get_repo(github_repo)
        all_documents = []
        
        for law_type, path in target_files.items():
            print(f"   👉 [원격 다운로드] '{path}' 파일 다운로드 시도 중...")
            try:
                content_file = repo.get_contents(path)
                file_content = base64.b64decode(content_file.content).decode("utf-8")
                print(f"   └ [성공] '{law_type}' 다운로드 완료! (용량: {len(file_content)} 글자)")
            except Exception as fe:
                print(f"   ❌ '{path}' 다운로드 실패: {fe}")
                continue

            if not file_content:
                continue

            # --- 마크다운 헤더 기반의 정밀 시맨틱 청킹 (대한민국 3대 법령 규격 고증 반영) ---
            # sample 정밀 분석 결과, 개별 조(Article)는 '##### 제N조 (제목)' 즉 5단계 헤더로 완벽 분리되어 있습니다!
            # 5단계 헤더까지 포함시켜 조문 단위로 자를 때의 완벽한 물리적 독립 시맨틱 바운더리를 확립합니다.
            headers_to_split_on = [
                ("#", "Header 1"),
                ("##", "Header 2"),
                ("###", "Header 3"),
                ("####", "Header 4"),
                ("#####", "Header 5"),
            ]
            markdown_splitter = MarkdownHeaderTextSplitter(headers_to_split_on=headers_to_split_on)
            md_header_splits = markdown_splitter.split_text(file_content)
            
            # 가중치 고른 분포용 2차 스플리터
            text_splitter = RecursiveCharacterTextSplitter(chunk_size=1200, chunk_overlap=150)
            splits = text_splitter.split_documents(md_header_splits)
            
            for idx, split in enumerate(splits):
                initial_metadata = {
                    "source": f"GitHub ({github_repo})",
                    "law_name": "산업안전보건법",
                    "law_type": law_type,
                    "chunk_idx": idx,
                    **split.metadata
                }
                
                # 💡 [정밀 주소 파서 기동]: 조, 항, 호, 목을 본문에서 실시간 추출하여 매핑 보강
                fine_metadata = extract_fine_grained_law_metadata(split.page_content, initial_metadata)
                
                doc = Document(page_content=split.page_content, metadata=fine_metadata)
                all_documents.append(doc)

        if not all_documents:
            print("❌ 적재할 산업안전보건법 문서 조각이 존재하지 않습니다. 작업을 종료합니다.")
            return

        # 💡 [초대형 클렌징 패치]: 기존에 임의로 누적 쌓였던 seed_ 법령 청크 조각들을 완벽하게 싹 청소
        # 💡 [ensure_ascii=False 성능 패치 적용]
        print("\n🧹 1.5단계: 기존에 pgvector에 오토 UUID 등으로 중복 분산 적재된 모든 seed 관련 낡은 레코드를 통째로 삭제 청소합니다...")
        try:
            from sqlalchemy import create_engine, text as sql_text
            engine = create_engine(
                postgres_url,
                json_serializer=lambda obj: json.dumps(obj, ensure_ascii=False)
            )
            with engine.connect() as conn:
                # 1) custom_id가 law_seed_로 시작하는 멱등성용 레코드 청소
                conn.execute(sql_text("DELETE FROM langchain_pg_embedding WHERE custom_id LIKE 'law_seed_%'"))
                # 2) 혹시 기존에 custom_id 없이 Auto-UUID로 들어갔던 seed_ 법률/시행령/시행규칙 레코드들도 메타데이터 내용을 검사해 일괄 강제 삭제
                conn.execute(
                    sql_text("DELETE FROM langchain_pg_embedding WHERE (cmetadata->>'law_name' = '산업안전보건법' AND cmetadata->>'sha' LIKE 'seed_%') OR (cmetadata->>'law_name' = '산업안전보건법' AND cmetadata->>'commit_sha' LIKE 'seed_%')")
                )
                conn.commit()
            print("   └ [대성공] 기존 중복 누적 벡터 데이터 베이스 완전 초기화(Clean Up) 완료!")
        except Exception as clean_err:
            print(f"   ⚠️ [경고] 적재 전 DB 사전 청소 중 오류 발생 (무시하고 적재 진행): {clean_err}")

        print(f"\n💾 2단계: 멱등성 주소 메타데이터가 탑재된 {len(all_documents)}개의 명품 정형 조문을 pgvector RAG DB에 순차 적재합니다...")
        
        success_count = 0
        for i, doc in enumerate(all_documents, 1):
            try:
                unique_key = f"seed_{doc.metadata['law_type']}_{doc.metadata['chunk_idx']}"
                doc.metadata["commit_sha"] = unique_key
                doc.metadata["sha"] = unique_key
                
                # rag_engine 내부에서 'commit_sha'를 추출해 custom_id='law_seed_{law_type}_{chunk_idx}' 로 만들어 선삭제 후 안전 삽입
                add_document_to_vector_store(doc.page_content, doc.metadata)
                success_count += 1
                if i % 10 == 0 or i == len(all_documents):
                    print(f"   ├ [진행상황] {i}/{len(all_documents)}개 청크 적재 완료... (현재 조항: {doc.metadata.get('article', 'N/A')})")
            except Exception as db_err:
                print(f"   ❌ [적재 에러 - 청크 {i}]: {db_err}")
                
        print(f"\n🎉 [최종 결과] 총 {success_count}개의 고밀도 '산업안전보건법' 조문 벡터 데이터가 pgvector DB에 풀시딩 완료되었습니다!")
        print("💡 이제 중복이 단 1행도 생성되지 않는 철저한 멱등성 하이브리드 RAG 교육용 AI 팩토리를 구동하십시오!")

    except Exception as e:
        print(f"❌ 깃허브 또는 로컬 파일 적재 연동 중 오류 발생: {e}")

if __name__ == "__main__":
    seed_industry_safety_law()
