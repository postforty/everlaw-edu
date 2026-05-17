import os
import sys
import base64
import json
from github import Github
from langchain_text_splitters import MarkdownHeaderTextSplitter, RecursiveCharacterTextSplitter
from langchain_core.documents import Document

# scripts 폴더의 부모인 ai-engine을 sys.path에 추가하여 app 패키지를 찾을 수 있도록 함
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.config import GITHUB_REPO, GITHUB_TOKEN, POSTGRES_URL
from app.ingestion.parser import extract_fine_grained_law_metadata, split_law_markdown_to_documents

def seed_industry_safety_law():
    github_repo = GITHUB_REPO
    github_token = GITHUB_TOKEN
    postgres_url = POSTGRES_URL
    
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

            # 💡 [공통 파이프라인 통합]: seed.py와 scheduler.py가 100% 동일한 파서 & 메타데이터 주소 기동!
            docs = split_law_markdown_to_documents(
                file_content=file_content,
                law_name="산업안전보건법",
                law_type=law_type,
                source=f"GitHub ({github_repo})"
            )
            all_documents.extend(docs)

        if not all_documents:
            print("❌ 적재할 산업안전보건법 문서 조각이 존재하지 않습니다. 작업을 종료합니다.")
            return

        # 💡 [초대형 클렌징 패치]: 기존에 임의로 누적 쌓였던 모든 산업안전보건법 및 seed 레코드들을 완전 청소
        print("\n🧹 1.5단계: 기존에 pgvector에 누적 적재된 산업안전보건법 관련 모든 낡은 레코드를 통째로 삭제 청소합니다...")
        try:
            from sqlalchemy import create_engine, text as sql_text
            engine = create_engine(
                postgres_url,
                json_serializer=lambda obj: json.dumps(obj, ensure_ascii=False)
            )
            with engine.connect() as conn:
                # 1) custom_id가 law_seed_로 시작하는 예외적 헤더 레코드 청소
                conn.execute(sql_text("DELETE FROM langchain_pg_embedding WHERE custom_id LIKE 'law_seed_%'"))
                # 2) 새로 도입된 비즈니스 멱등성 키 (law_산업안전보건법_제N조) 및 일반 메타데이터 일괄 물리 삭제 단행
                conn.execute(
                    sql_text("DELETE FROM langchain_pg_embedding WHERE custom_id LIKE 'law_산업안전보건법_%' OR cmetadata->>'law_name' = '산업안전보건법'")
                )
                conn.commit()
            print("   └ [대성공] 기존 중복 누적 벡터 데이터 베이스 완전 초기화(Clean Up) 완료!")
        except Exception as clean_err:
            print(f"   ⚠️ [경고] 적재 전 DB 사전 청소 중 오류 발생 (무시하고 적재 진행): {clean_err}")

        # scripts 폴더의 부모인 ai-engine을 sys.path에 추가하여 app 패키지를 찾을 수 있도록 함
        from app.core.database import add_documents_to_vector_store_bulk
        
        print(f"\n💾 2단계: 멱등성 주소 메타데이터가 탑재된 {len(all_documents)}개의 명품 정형 조문을 pgvector RAG DB에 고속 벌크 적재합니다...")
        
        # 1. 비조항 청크(부칙, 목적 등)에 대해 law_id 기반의 결정론적 fallback 키 전처리 보장
        for doc in all_documents:
            if not doc.metadata.get("article"):
                doc.metadata["law_id"] = f"seed_{doc.metadata['law_name']}_{doc.metadata['law_type']}_{doc.metadata['chunk_idx']}"
        
        # 2. 단일 배치 트랜잭션으로 벌크 적재 (Ollama 단 1번 호출)
        add_documents_to_vector_store_bulk(all_documents)
        success_count = len(all_documents)
                
        print(f"\n🎉 [최종 결과] 총 {success_count}개의 고밀도 '산업안전보건법' 조문 벡터 데이터가 pgvector DB에 풀시딩 완료되었습니다!")
        print("💡 이제 중복이 단 1행도 생성되지 않는 철저한 멱등성 하이브리드 RAG 교육용 AI 팩토리를 구동하십시오!")

    except Exception as e:
        print(f"❌ 깃허브 또는 로컬 파일 적재 연동 중 오류 발생: {e}")

if __name__ == "__main__":
    seed_industry_safety_law()
