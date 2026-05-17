from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.core.database import retrieve_affected_curriculum, add_curriculum_to_vector_store
from app.services.graph_workflow import generate_rag_content

router = APIRouter()

class LawChangeRequest(BaseModel):
    law_id: str
    content: str
    metadata: Optional[dict] = None

class CurriculumSeedRequest(BaseModel):
    lesson_id: int
    curriculum_id: int
    title: str
    content: str

@router.get("/status")
async def status():
    return {
        "status": "Healthy",
        "message": "EverLaw Edu AI Engine is processing inputs"
    }

@router.post("/analyze-impact")
async def analyze_impact(request: LawChangeRequest):
    try:
        # 개정 법령 본문을 기준으로 pgvector에 등록된 연관 교육 커리큘럼(강의) 검색
        affected_lessons = retrieve_affected_curriculum(request.content)
        
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
        # RAG 엔진 호출 (차분 분석 & 구조화 JSON 및 마크다운 동시 생성)
        result = generate_rag_content(request.content)
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
