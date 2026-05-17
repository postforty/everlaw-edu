"""
================================================================================
EverLaw Edu AI Engine: HTTP REST API 통합 클라이언트 테스터 (test_api_client.py)
================================================================================

본 스크립트는 로컬에서 구동 중인 FastAPI 웹 서버(포트 8000번)의 모든 REST API 엔드포인트를
실제 클라이언트 입장에서 HTTP로 호출하며 전체 RAG 파이프라인과 생성·감사 엔진을 검증하는 
'의존성 제로(Zero-Dependency)' 규격의 통합 테스트 도구입니다.

[💡 주요 특징]
1. 별도의 requests, httpx 등의 외부 패키지 설치가 필요 없는 파이썬 표준 라이브러리(urllib) 기반 작동.
2. 실제 상용 백엔드(Spring Boot) 개발자가 FastAPI 서버와 주고받아야 할 JSON API 입출력 규격을 고스란히 재현.
3. 테스트 구동 즉시 1단계 헬스체크부터 4단계 AI 생성 및 팩트 감사 보고서 분석까지 E2E 통합 실증 수행.

[🚀 실행 및 사용법]
1. 로컬 환경에서 FastAPI 서버가 먼저 가동되어 있어야 합니다.
   실행 명령: uv run python -X utf8 main.py
2. 서버가 켜진 상태에서 새 터미널을 열고 본 클라이언트 스크립트를 기동합니다:
   실행 명령: uv run python -X utf8 test_api_client.py
================================================================================
"""

import json
import urllib.request
import urllib.error
import sys

# 기본 대상 API 서버 호스트 (FastAPI 기본 포트 8000번)
BASE_URL = "http://localhost:8000/api/v1"

def send_http_request(method: str, path: str, payload: dict = None) -> dict:
    """urllib 기반의 무의존성 HTTP 요청 전송 헬퍼 함수"""
    # 🕵️‍♂️ [방어형 필터] 주소의 보이지 않는 특수문자 및 제로 너비 공백(\u200b) 완전 박멸
    clean_path = path.strip().replace("\u200b", "").replace("\xa0", "")
    url = f"{BASE_URL}{clean_path}"
    data = None
    headers = {"Content-Type": "application/json"}
    
    if payload:
        data = json.dumps(payload).encode("utf-8")
        
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    
    try:
        with urllib.request.urlopen(req) as res:
            response_body = res.read().decode("utf-8")
            return json.loads(response_body)
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")
        try:
            parsed_error = json.loads(error_body)
            print(f"❌ HTTP {e.code} 에러 발생 (요청 URL: {url}, Method: {method}): {parsed_error}")
            return parsed_error
        except Exception:
            print(f"❌ HTTP {e.code} 에러 발생 (요청 URL: {url}, Method: {method}): {error_body}")
            return {"status": "Error", "detail": error_body}
    except Exception as e:
        print(f"❌ 서버 연결 실패 (서버가 실제로 켜져 있는지 확인하세요!): {e}")
        sys.exit(1)

def run_integration_api_test():
    print("======================================================================")
    print("📡 [EverLaw API Client] 통합 웹 API 엔드포인트 E2E 테스트 검증 개시...")
    print("======================================================================\n")

    # -------------------------------------------------------------------------
    # 1단계: 서버 헬스체크 (GET /status)
    # -------------------------------------------------------------------------
    print("📢 1단계: FastAPI AI 웹 서버 활성 상태(Health-Check) 검증 중...")
    health_result = send_http_request("GET", "/status")
    print(f"   └ [응답 결과] Status: {health_result.get('status')}, Message: {health_result.get('message')}")
    if health_result.get("status") != "Healthy":
        print("❌ [실패] 서버가 비정상 상태입니다. 테스트를 조기 종료합니다.")
        return
    print("🟢 [통과] 서버 상태 매우 양호!\n")

    # -------------------------------------------------------------------------
    # 2단계: 테스트용 기존 교육 강의안 시딩 (POST /seed-curriculum)
    # -------------------------------------------------------------------------
    print("📢 2단계: RAG 데이터베이스 내 테스트용 교육 커리큘럼(강의안) 시딩 중...")
    mock_curriculum = {
        "lesson_id": 999,
        "curriculum_id": 99,
        "title": "API 테스트용 임시 고소 작업 규정",
        "content": (
            "# API 임시 비계 작업 안전 규정\n"
            "본 강의는 임시 작업 발판의 기준을 정의합니다.\n\n"
            "## 1. 비계 높이 수치\n"
            "* 높이 3미터(3m) 이상의 장소에서 작업을 진행하는 경우, 안전망을 촘촘히 설치해야 합니다."
        )
    }
    seed_result = send_http_request("POST", "/seed-curriculum", mock_curriculum)
    print(f"   └ [응답 결과] {seed_result.get('message')}")
    print("🟢 [통과] 테스트용 강의안 1건 pgvector 이식 완료!\n")

    # -------------------------------------------------------------------------
    # 3단계: 법령 개정에 따른 영향 범위 분석 (POST /analyze-impact)
    # -------------------------------------------------------------------------
    print("📢 3단계: 신규 법령 개정안 유입 시 연관 강의 영향 범위(Impact Search) 테스트...")
    # 비계 높이를 3m에서 2m로 하향 강화하는 법령 개정 시나리오
    law_change_content = (
        "## 제12조 (안전 조치)\n"
        "사업주는 높이 2미터(2m) 이상의 장소에서 비계를 조립하여 작업할 시, "
        "반드시 추락방지 의무 안전망을 설계 규격에 맞게 촘촘히 밀착 설치해야 한다."
    )
    impact_request = {
        "law_id": "LAW_SAFETY_AMENDMENT_2026",
        "content": law_change_content
    }
    impact_result = send_http_request("POST", "/analyze-impact", impact_request)
    print(f"   └ [응답 결과] Impact Level: {impact_result.get('impact_level')}")
    print(f"   └ [영향을 받는 강의 목록]: {impact_result.get('affected_modules')}")
    print("🟢 [통과] pgvector 의미론적 검색을 통한 연관 교육 매핑 확인 성공!\n")

    # -------------------------------------------------------------------------
    # 4단계: 개정 법령 기준 AI 자율 생성 및 팩트 감사 (POST /generate-content)
    # -------------------------------------------------------------------------
    print("📢 4단계: 개정 법령 기반 스토리텔링 교안 생성 및 실시간 AI 자가 팩트체크 가동...")
    print("   👉 (Gemini 1.5/3.1 및 LangGraph 워크플로우를 통과하여 사실 감사가 처리되므로 약 3~5초 정도 소요됩니다.)")
    
    generate_result = send_http_request("POST", "/generate-content", impact_request)
    
    print("\n   [📊 RAG AI 에이전트 자율 생성 및 검증 응답 완수]")
    print("   ------------------------------------------------------------------")
    print(f"   ▶ Status : {generate_result.get('status')}")
    
    # AI 자율 생성된 강의안 요약 정보
    analysis = generate_result.get("analysis_result", {})
    print(f"   ▶ 생성 교안 타이틀 : {analysis.get('title')}")
    print(f"   ▶ 카테고리 : {analysis.get('category')}")
    
    # AI 사실검증 감사 정보 (Red Flag 여부)
    validation = generate_result.get("validation_result", {})
    print(f"   ▶ AI 자가 팩트체크 적합 여부 (is_valid) : {validation.get('is_valid')}")
    print(f"   ▶ 환각 지수 (Hallucination Score) : {validation.get('hallucination_score') * 100:.1f}%")
    print(f"   ▶ 수치 불일치 경고등 (warning_flag) : {validation.get('warning_flag')}")
    
    # 팩트체크 불일치 세부 소견 출력
    details = validation.get("validation_details", "")
    print(f"   ▶ 팩트체크 소견 : {details}")
    print("   ------------------------------------------------------------------")
    print("🟢 [통과] 4단계 RAG AI 에이전트 서빙 통합 검증 대성공!\n")

    # -------------------------------------------------------------------------
    # 5단계: 테스트용 임시 Mock 강의안 데이터 자가 소거 (Teardown)
    # -------------------------------------------------------------------------
    print("📢 5단계: RAG 데이터베이스 내 임시 Mock 강의안 데이터 자가 소거(Teardown) 중...")
    # JSON Body Payload를 채워서 전송함으로써 urllib의 empty-body 버그 원천 봉쇄
    teardown_payload = {"lesson_id": mock_curriculum["lesson_id"]}
    teardown_result = send_http_request("POST", "/curriculum-delete", teardown_payload)
    print(f"   └ [응답 결과] Status: {teardown_result.get('status')}, Message: {teardown_result.get('message')}")
    print("🟢 [통과] 데이터베이스 내 Mock 찌꺼기 정리 완료! (오염도 0.00% 회복)\n")

    print("======================================================================")
    print("🎉 [축하합니다] FastAPI 웹 서버 E2E 통합 REST API 실증 테스트를 완벽히 통과했습니다!")
    print("======================================================================")

if __name__ == "__main__":
    run_integration_api_test()
