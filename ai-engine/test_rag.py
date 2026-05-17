import os
import sys
import json
from dotenv import load_dotenv

# ai-engine 폴더를 python path에 추가하여 내부 모듈 참조 가능하게 설정
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", "..", "..", "Documents", "GitHub", "everlaw-edu", "ai-engine"))
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "ai-engine")))
sys.path.append("c:\\Users\\dandycode\\Documents\\GitHub\\everlaw-edu\\ai-engine")

load_dotenv(dotenv_path="c:\\Users\\dandycode\\Documents\\GitHub\\everlaw-edu\\ai-engine\\.env")

try:
    from app.core.database import add_curriculum_to_vector_store, retrieve_affected_curriculum
    from app.services.graph_workflow import generate_rag_content
    from app.ingestion.scheduler import LawScanner
    from app.ingestion.parser import extract_added_text_from_patch
    print("✅ RAG Engine 및 Law Scanner 모듈 로드 완료!")
except ImportError as e:
    print(f"❌ RAG Engine 및 Scanner 로드 실패: {e}")
    sys.exit(1)

# --- 1. Mock 교육 커리큘럼 데이터 준비 ---
MOCK_CURRICULA = [
    {
        "lesson_id": 101,
        "curriculum_id": 1,
        "title": "제조업 비계 작업 안전 규정",
        "content": """# 제조업 비계 작업 안전 수칙
본 강의에서는 고소 작업 시 발생할 수 있는 추락 사고를 예방하기 위한 비계 설치 및 관리 요령을 학습합니다.

## 1. 비계 설치 기준
* 비계의 설치 및 해체는 숙련된 전문가에 의해 진행되어야 합니다.
* 높이 3미터(3m) 이상의 장소에서 작업을 진행하는 경우, 근로자의 추락 위험을 방지하기 위하여 반드시 규격에 맞는 추락 방지 안전망을 촘촘히 의무 설치해야 합니다.
* 작업 발판의 폭은 40cm 이상으로 유지해야 하며 발판 틈새는 3cm 이하로 고정합니다."""
    },
    {
        "lesson_id": 202,
        "curriculum_id": 2,
        "title": "스쿨존 교통 안전 지침",
        "content": """# 어린이 보호구역(스쿨존) 운행 지침
어린이들의 안전한 통학로 확보를 위한 도로교통법 제12조 특별 안전 규정을 학습합니다.

## 1. 운행 제한 속도
* 어린이 보호구역 내에서는 차량의 제한 속도가 시속 30km 이하로 엄격히 제한됩니다.
* 신호등이 없는 횡단보도 앞에서는 보행자 유무와 관계없이 반드시 일시정지(1초 이상) 후 서행해야 합니다.
* 위반 시에는 벌점 및 일반 도로 대비 2배의 과태료가 가중 부과됩니다."""
    }
]

# --- 2. 신규 개정 법령 텍스트 (RAG 검색 쿼리) ---
NEW_LAW_CHANGE = """
[산업안전보건법 제38조 개정 통과]
고소 작업 현장의 안전 기준 강화를 위해 비계 조항이 개정되었습니다. 
근로자 추락 방지망의 의무 설치 기준 높이가 기존 '3미터(3m) 이상'에서 '2미터(2m) 이상'의 고소 작업 장소로 대폭 강화됩니다. 
이를 위반할 경우 사업주에게 엄중한 벌칙 및 과태료가 부과될 수 있습니다. (시행일: 즉시)
"""

def run_retrieval_test():
    print("\n==============================================")
    print("📡 0단계: GitHub API 실시간 개정 법령 스캔 테스트")
    print("==============================================")
    print("👉 'legalize-kr/legalize-kr' 레포지토리 실시간 조회 중...")
    try:
        scanner = LawScanner()
        repo = scanner.gh.get_repo(scanner.github_repo)
        commits = [c for c in repo.get_commits()[:3]]  # 리스트 컴프리헨션으로 확실하게 형변환
        
        print(f"✅ 성공적으로 원격 레포지토리에 연결되었습니다!")
        print(f"   └ 대상 저장소: {scanner.github_repo}")
        print(f"   └ 최근 {len(commits)}개의 실제 변경 이력(커밋)을 상세 분석합니다:")
        
        for commit in commits:
            print(f"\n   [커밋 SHA: {commit.sha[:8]}]")
            print(f"   ├ 메시지: {commit.commit.message.splitlines()[0]}")
            print(f"   ├ 작성일자: {commit.commit.author.date}")
            print(f"   └ 변경 파일 분석:")
            for file in commit.files:
                print(f"      - 파일명: {file.filename} (상태: {file.status}, 추가 {file.additions}줄)")
                if file.filename.endswith('.md') and file.patch:
                    print(f"         └ 🔍 마크다운 패치 데이터 감지!")
                    added_text = extract_added_text_from_patch(file.patch)
                    if added_text:
                        print(f"         └ ✍️ 정제된 실질 개정 텍스트 (상위 150자):\n\"\"\"\n{added_text[:150]}...\n\"\"\"")
                        print(f"         └ 🟢 벡터스토어 적재용 추출 성공!")
                    else:
                        print(f"         └ ⚠️ (개정 텍스트 파싱 결과 의미 있는 법 조문이 비어있음)")
    except Exception as e:
        print(f"❌ GitHub API 스캔 중 에러 발생: {e}")
        print("   ⚠️ (인터넷 연결 상태 및 깃허브 API 레이트 리밋 제한을 확인해 주세요.)")

    print("\n==============================================")
    print("🚀 1단계: RAG 백업 벡터스토어 시딩(Seeding) 테스트")
    print("==============================================")
    for cur in MOCK_CURRICULA:
        print(f"👉 강의안 시딩 중: '{cur['title']}'...")
        metadata = {
            "lesson_id": cur["lesson_id"],
            "curriculum_id": cur["curriculum_id"],
            "title": cur["title"]
        }
        try:
            add_curriculum_to_vector_store(cur["content"], metadata)
            print(f"   └ [성공] '{cur['title']}' 적재 완료!")
        except Exception as e:
            print(f"   └ [실패] 적재 에러: {e}")
            print("   ⚠️ (로컬 PostgreSQL pgvector 컨테이너 및 Ollama가 실행 중인지 확인이 필요합니다)")
            return

    print("\n==============================================")
    print("🔍 2단계: 개정 법령 기반 연관 강의안 Retriever 검색 테스트")
    print("==============================================")
    print(f"입력 개정 법령: {NEW_LAW_CHANGE.strip()}")
    print("----------------------------------------------")
    try:
        results = retrieve_affected_curriculum(NEW_LAW_CHANGE)
        print(f"🎯 검색 완료! 총 {len(results)}개의 강의가 후보군으로 조회되었습니다.")
        
        for idx, res in enumerate(results, 1):
            print(f"[{idx}순위 매칭 강의]")
            print(f"   - Lesson ID: {res['lesson_id']}")
            print(f"   - Title: {res['title']}")
            print(f"   - Content (일부): {res['content'][:150]}...")
            print("----------------------------------------------")
    except Exception as e:
        print(f"❌ Retriever 실행 중 에러 발생: {e}")
        return

    print("\n==============================================")
    print("🤖 3단계: Gemini 연동 차분 분석 및 AI 검증(Validation) 테스트")
    print("==============================================")
    try:
        print("💡 Gemini 에이전트 분석 기동 중 (LangGraph 파이프라인)...")
        rag_output = generate_rag_content(NEW_LAW_CHANGE)
        
        print("\n📊 [1] 구조화 JSON 분석 데이터 (analysis_result):")
        print(json.dumps(rag_output["analysis_result"], indent=2, ensure_ascii=False))
        
        print("\n🛡️ [2] AI 자가 검증 결과 데이터 (validation_result):")
        print(json.dumps(rag_output["validation_result"], indent=2, ensure_ascii=False))
        
        print("\n📝 [3] 최종 관리자 보고서 (markdown_report):")
        print(rag_output["markdown_report"])
        
    except Exception as e:
        print(f"❌ Gemini 분석 파이프라인 구동 실패: {e}")

if __name__ == "__main__":
    run_retrieval_test()
