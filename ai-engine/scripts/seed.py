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
                # 3) 기존 curriculum_documents 컬렉션의 낡은 마스터 챕터 강의안(custom_id가 lesson_로 시작)들도 일체 청소
                conn.execute(sql_text("DELETE FROM langchain_pg_embedding WHERE custom_id LIKE 'lesson_%'"))
                conn.commit()
            print("   └ [대성공] 기존 중복 누적 벡터 데이터 베이스 완전 초기화(Clean Up) 완료!")
        except Exception as clean_err:
            print(f"   ⚠️ [경고] 적재 전 DB 사전 청소 중 오류 발생 (무시하고 적재 진행): {clean_err}")

        # scripts 폴더의 부모인 ai-engine을 sys.path에 추가하여 app 패키지를 찾을 수 있도록 함
        from app.core.database import add_documents_to_vector_store_bulk, add_curriculum_to_vector_store
        
        print(f"\n💾 2단계: 멱등성 주소 메타데이터가 탑재된 {len(all_documents)}개의 명품 정형 조문을 pgvector RAG DB에 고속 벌크 적재합니다...")
        
        # 1. 비조항 청크(부칙, 목적 등)에 대해 law_id 기반의 결정론적 fallback 키 전처리 보장
        for doc in all_documents:
            if not doc.metadata.get("article"):
                doc.metadata["law_id"] = f"seed_{doc.metadata['law_name']}_{doc.metadata['law_type']}_{doc.metadata['chunk_idx']}"
        
        # 2. 단일 배치 트랜잭션으로 벌크 적재 (Ollama 단 1번 호출)
        add_documents_to_vector_store_bulk(all_documents)
        success_count = len(all_documents)
        print(f"   └ [성공] 총 {success_count}개의 고밀도 '산업안전보건법' 조문 벡터 데이터가 pgvector DB에 풀시딩 완료되었습니다!")

        print("\n🎓 3단계: 산업안전보건법 마스터 커리큘럼 4대 핵심 챕터 기본 시딩을 시작합니다...")
        master_chapters = [
            {
                "lesson_id": 1,
                "curriculum_id": 101,
                "title": "산업안전보건법 총칙 및 보건 확보 의무",
                "content": """# 산업안전보건법 총칙 및 보건 확보 의무
본 강의에서는 산업안전보건법의 기본 목적과 근로자의 안전 및 보건을 유지·증진하기 위한 사업주 및 경영책임자의 기본 보건 확보 의무를 명확히 이해합니다.

## 1. 법의 목적 및 기본 책무
* **산업재해 예방**: 산업 안전 및 보건에 관한 기준을 확립하고, 그 책임의 한계를 명확하게 하여 산업재해를 예방합니다.
* **쾌적한 작업환경 조성**: 안전하고 쾌적한 작업환경을 조성함으로써 현장 근로자의 생명과 신체 건강을 보호합니다.
* **보건 확보 의무**: 경영책임자는 현장의 보건 조치와 위생 관리에 필요한 예산 및 체계를 실질적으로 구축해야 합니다.

## 2. 근로자의 기본 의무
* 근로자는 사업주가 행하는 산업재해 예방을 위한 모든 조치와 규칙(보호구 착용, 안전 수칙 준수)을 철저히 준수해야 합니다.

---

### 📝 [QUIZ] 산업안전보건법 제4조(사업주 등의 의무)에 의거하여, 사업장에서 산업재해를 예방하기 위한 안전 및 보건 조치를 마련하고 쾌적한 작업환경을 조성해야 할 주된 법적 주체는 누구입니까?
1) 노동조합
2) 개별 근로자
3) 사업주 및 경영책임자
4) 지방고용노동관서"""
            },
            {
                "lesson_id": 2,
                "curriculum_id": 102,
                "title": "위험성평가(Risk Assessment) 구축 및 실무",
                "content": """# 위험성평가(Risk Assessment) 구축 및 실무
본 강의에서는 현장의 유해·위험요인을 스스로 파악하여 부상 또는 질병의 발생 가능성과 중대성을 추정·결정하고 감소 대책을 수립하는 '위험성평가'의 단계별 실무 프로세스를 다룹니다.

## 1. 위험성평가 프로세스
* **1단계 (사전준비)**: 평가 대상을 선정하고 안전보건 정보를 수집합니다.
* **2단계 (유해·위험요인 파악)**: 순회 점검, 근로자 제안 등을 통해 유해·위험요인을 도출합니다.
* **3단계 (위험성 결정)**: 유해 요인이 실제 사고로 이어질 수 있는 빈도와 강도를 교차 평가합니다.
* **4단계 (위험성 감소대책 수립 및 실행)**: 평가된 위험도가 허용 범위를 초과하는 경우 조치 예산을 우선 투입하여 즉시 제거합니다.

## 2. 정기 및 수시 평가
* **정기 평가**: 매년 정기적으로 실시하여 유해 요인을 주기적으로 관리합니다.
* **수시 평가**: 기계 설비 도입, 중대재해 발생 등 공정에 변동이 있을 때 즉시 재평가해야 합니다.

---

### 📝 [QUIZ] 위험성평가(Risk Assessment)의 단계별 절차 중, 현장의 유해·위험 요인들을 찾아내기 위해 순회 점검 및 근로자 면담을 실시하는 가장 첫 번째 유해 요인 관리 실무 단계는 무엇일까요?
1) 사전준비 및 계획 수립
2) 유해·위험요인 파악
3) 위험성 감소대책 수립 및 실행
4) 평가 결과의 기록 및 보존"""
            },
            {
                "lesson_id": 3,
                "curriculum_id": 103,
                "title": "고소 작업 및 비계 설치 안전 기준",
                "content": """# 고소 작업 및 비계 설치 안전 기준
본 강의에서는 건설 및 제조업 현장에서 빈번히 발생하는 추락 사고를 예방하기 위한 고소 작업 비계 설치 기준 및 안전 조치 요령을 철저히 학습합니다.

## 1. 비계 설치 핵심 기준
* **안전망 설치 기준**: 높이 3미터(3m) 이상의 장소에서 작업을 진행하는 경우, 근로자의 추락 위험을 방지하기 위하여 반드시 규격에 맞는 추락 방지 안전망을 촘촘히 의무적으로 설치해야 합니다. (주의: 개정법 추적 필요)
* **작업발판 규격**: 발판 폭은 40cm 이상, 발판 틈새는 3cm 이하를 엄격히 엄수해야 합니다.
* **비계의 고정**: 강풍 및 충격에 비계가 흔들리거나 무너지지 않도록 단단히 벽체에 고정해야 합니다.

## 2. 근로자 개인 보호구
* 고소 작업 근로자는 안전모와 안전대를 반드시 착용하고, 생명줄에 안전대 고리를 이중 체결한 상태에서만 이동 및 작업해야 합니다.

---

### 📝 [QUIZ] 본 강좌의 비계 설치 및 고소 작업 안전 기준에 의거하여, 비계 위에서 작업을 수행할 때 근로자가 추락하는 것을 원천 방지하기 위해 설치하는 작업 발판의 최소 폭 규격은 어떻게 될까요?
1) 20cm 이상
2) 30cm 이상
3) 40cm 이상
4) 50cm 이상"""
            },
            {
                "lesson_id": 4,
                "curriculum_id": 104,
                "title": "산업안전보건법 위반 시 벌칙 및 형사처벌",
                "content": """# 산업안전보건법 위반 시 벌칙 및 형사처벌
본 강의에서는 산업재해 예방 의무를 저버리거나 안전·보건 조치를 게을리하여 사고가 발생했을 때 부과되는 강력한 형사 처벌 기준 및 벌금 체계를 상세히 파악합니다.

## 1. 안전보건조치 의무 위반 시 처벌 (제167조)
* **의무 위반**: 안전·보건조치 의무를 위반하여 근로자를 사망에 이르게 한 자는 **7년 이하의 징역** 또는 **1억원 이하의 벌금**에 처해집니다.
* **상습범 가중**: 5년 이내에 다시 동일한 위반으로 근로자를 사망에 이르게 한 경우 그 형의 2분의 1까지 가중 처벌됩니다.

## 2. 법인에 대한 양벌규정 (제173조)
* 의무 위반으로 근로자 사망 시 행위자 처벌 외에도 법인에게 **10억원 이하의 벌금**을 부과하여 재정적 책임을 강력히 묻습니다.

---

### 📝 [QUIZ] 산업안전보건법 제167조에 따라, 안전보건조치 의무를 위반함으로써 현장 근로자를 사망에 이르게 한 사업주 또는 책임자 개인에게 부과될 수 있는 형사 처벌의 법정형 상한선은 어떻게 될까요?
1) 1년 이하의 징역 또는 1천만원 이하의 벌금
2) 3년 이하의 징역 또는 3천만원 이하의 벌금
3) 5년 이하의 징역 또는 5천만원 이하의 벌금
4) 7년 이하의 징역 또는 1억원 이하의 벌금"""
            }
        ]

        for idx, cur in enumerate(master_chapters, 1):
            print(f"   👉 [마스터 시딩] 챕터 {idx}: '{cur['title']}'...")
            metadata = {
                "lesson_id": cur["lesson_id"],
                "curriculum_id": cur["curriculum_id"],
                "title": cur["title"]
            }
            try:
                add_curriculum_to_vector_store(cur["content"], metadata)
                print(f"   └ [성공] 챕터 {idx} 적재 완료!")
            except Exception as se:
                print(f"   ❌ 챕터 {idx} 적재 실패: {se}")

        print("\n🎉 [최종 결과] '산업안전보건법 마스터 커리큘럼 4대 핵심 챕터' 및 조문 벡터 데이터가 pgvector DB에 풀시딩 완료되었습니다!")
        print("💡 이제 4대 핵심 마스터 코스를 기반으로 완벽한 핫스왑 RAG 지식 공장을 가동하십시오!")

    except Exception as e:
        print(f"❌ 깃허브 또는 로컬 파일 적재 연동 중 오류 발생: {e}")

if __name__ == "__main__":
    seed_industry_safety_law()

