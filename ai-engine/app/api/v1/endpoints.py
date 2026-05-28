from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.core.database import retrieve_affected_curriculum, retrieve_affected_curriculum_async, add_curriculum_to_vector_store, engine
from app.services.graph_workflow import generate_rag_content, generate_rag_content_async

router = APIRouter()

print(f"🔥 [물리 임포트 추적] endpoints.py 로드 완료! (물리 경로: {__file__})")


class LawChangeRequest(BaseModel):
    law_id: str
    content: str
    metadata: Optional[dict] = None
    previous_questions: list[str] = []

class CurriculumSeedRequest(BaseModel):
    lesson_id: int
    curriculum_id: int
    title: str
    content: str

class CurriculumDeleteRequest(BaseModel):
    lesson_id: int

class AdaptiveQuizRequest(BaseModel):
    law_reference: str
    previous_questions: list[str] = []

class ChatRequest(BaseModel):
    message: str
    context: str = ""
    history: list[dict] = []

@router.get("/status")
async def status():
    return {
        "status": "Healthy",
        "message": "EverLaw Edu AI Engine is processing inputs"
    }

@router.post("/analyze-impact")
async def analyze_impact(request: LawChangeRequest):
    try:
        # 개정 법령 본문을 기준으로 pgvector에 등록된 연관 교육 커리큘럼(강의) 비동기 검색
        affected_lessons = await retrieve_affected_curriculum_async(request.content)
        
        # 검색 결과 유무에 따른 영향 수준 결정
        impact_level = "High" if affected_lessons else "Low"
        affected_modules = [f"Lesson {l['lesson_id']}: {l['title']}" for l in affected_lessons]
        
        return {
            "law_id": request.law_id,
            "impact_level": impact_level,
            "affected_modules": affected_modules,
            "details": affected_lessons,
            "status": "Success"
        }
    except Exception as e:
        return {
            "law_id": request.law_id,
            "impact_level": "Medium (Fallback)",
            "affected_modules": ["Error occurred during vector search"],
            "details": [],
            "error": str(e),
            "status": "Fallback"
        }

@router.post("/seed-curriculum")
async def seed_curriculum(request: CurriculumSeedRequest):
    """테스트용 기존 교육 커리큘럼을 RAG 벡터 DB에 적재하는 API"""
    try:
        metadata = {
            "lesson_id": request.lesson_id,
            "curriculum_id": request.curriculum_id,
            "title": request.title
        }
        add_curriculum_to_vector_store(request.content, metadata)
        return {
            "status": "Success",
            "message": f"Curriculum Lesson '{request.title}' successfully seeded."
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/generate-content")
async def generate_content(request: LawChangeRequest):
    try:
        # RAG 엔진 비동기 호출 (차분 분석 & 구조화 JSON 및 마크다운 동시 생성)
        result = await generate_rag_content_async(request.law_id, request.content, request.previous_questions)
        return {
            "law_id": request.law_id,
            "analysis_result": result["analysis_result"],
            "validation_result": result["validation_result"],
            "markdown_report": result["markdown_report"],
            "status": "Success"
        }
    except Exception as e:
        # 인프라 미준비 시 예외 처리 (PoC 단계 Fallback)
        return {
            "law_id": request.law_id,
            "analysis_result": {
                "lesson_id": -1,
                "title": "Fallback Mode",
                "category": "일반 컴플라이언스",
                "law_reference": "N/A",
                "content_markdown": f"# {request.law_id} 컴플라이언스 교안\n\n[폴백 모드]\n{request.content}",
                "quiz_proposed": "### [퀴즈]\n컴플라이언스 안전 규정을 준수해야 합니까?\n\n① 예\n② 아니오"
            },
            "validation_result": {
                "is_valid": False,
                "hallucination_score": 0.9,
                "validation_details": f"엔진 예외 발생 폴백: {str(e)}",
                "warning_flag": True
            },
            "markdown_report": f"[PoC Fallback] RAG 엔진 예외 발생: {str(e)}\n내용: {request.content[:100]}...",
            "status": "Partial Success (Fallback)"
        }

@router.post("/curriculum-delete")
async def delete_curriculum(request: CurriculumDeleteRequest):
    """테스트 후 생성했던 Mock 강의안 데이터를 pgvector DB에서 즉시 안전하게 소거하는 Teardown API"""
    try:
        from sqlalchemy import text as sql_text
        
        custom_id = f"lesson_{request.lesson_id}"
        with engine.connect() as conn:
            conn.execute(
                sql_text("DELETE FROM langchain_pg_embedding WHERE custom_id = :custom_id"),
                {"custom_id": custom_id}
            )
            conn.commit()
            
        return {
            "status": "Success",
            "message": f"Mock Curriculum Lesson '{request.lesson_id}' successfully cleaned up from vector store."
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/adaptive-quiz")
async def adaptive_quiz(request: AdaptiveQuizRequest):
    """지정된 법령을 기반으로 이전 문제들을 제외하고 즉석에서 새로운 변형 퀴즈를 출제합니다."""
    try:
        from app.services.adaptive_generator import generate_adaptive_quiz_async
        result = await generate_adaptive_quiz_async(request.law_reference, request.previous_questions)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/source-laws")
async def get_source_laws():
    """PGVector에 적재된 원본 법령 데이터를 중복 없이 반환합니다. (내용 제외, 정렬 적용)"""
    try:
        from sqlalchemy import text as sql_text
        import re
        
        laws = []
        with engine.connect() as conn:
            # cmetadata 컬럼을 파싱하여 law_name과 article만 반환
            query = sql_text("""
                SELECT DISTINCT ON (cmetadata->>'law_name', cmetadata->>'law_type', cmetadata->>'Header 2', cmetadata->>'article')
                       cmetadata->>'law_name' as law_name, 
                       cmetadata->>'law_type' as law_type,
                       cmetadata->>'Header 2' as header_2,
                       cmetadata->>'article' as article
                FROM langchain_pg_embedding
                WHERE cmetadata->>'law_name' IS NOT NULL 
                  AND cmetadata->>'article' IS NOT NULL
            """)
            result = conn.execute(query).fetchall()
            
            for row in result:
                law_name = row[0]
                law_type = row[1] if row[1] else "법률"
                header_2 = row[2] if row[2] else ""
                article = row[3]
                
                is_addenda = "부칙" in header_2
                addenda_str = " 부칙" if is_addenda else ""
                type_str = f" {law_type}" if law_type != "법률" else ""
                
                full_law_name = f"{law_name}{type_str}{addenda_str} {article}"
                
                laws.append({
                    "law_id": full_law_name,
                    "law_name": law_name,
                    "article": article,
                    "content": f"{full_law_name} 전문을 기반으로 한 퀴즈 생성을 지원합니다."
                })
                
        # Python Natural Sort
        def extract_number(text):
            match = re.search(r'\d+', text)
            return int(match.group()) if match else 0
            
        laws.sort(key=lambda x: (x['law_name'], extract_number(x['article'])))
        
        return {
            "status": "Success",
            "data": laws
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/chat")
async def chat_with_assistant(request: ChatRequest):
    """지정된 법령 컨텍스트와 이전 대화 기록을 바탕으로 질문에 답변합니다."""
    try:
        from app.services.chat_service import generate_chat_response_async
        response_text = await generate_chat_response_async(
            message=request.message,
            context=request.context,
            history=request.history
        )
        return {
            "status": "Success",
            "response": response_text
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

