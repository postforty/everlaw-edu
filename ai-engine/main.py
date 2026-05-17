from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional

app = FastAPI(title="EverLaw Edu AI Engine", version="0.1.0")

class LawChangeRequest(BaseModel):
    law_id: str
    content: str
    metadata: Optional[dict] = None

@app.get("/")
async def root():
    return {"message": "EverLaw Edu AI Engine is running"}

from rag_engine import retrieve_affected_curriculum, add_curriculum_to_vector_store

@app.post("/analyze-impact")
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

class CurriculumSeedRequest(BaseModel):
    lesson_id: int
    curriculum_id: int
    title: str
    content: str

@app.post("/seed-curriculum")
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

from rag_engine import generate_rag_content

@app.post("/generate-content")
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
                "impact_level": "Medium",
                "modifications": [
                    {
                        "is_modification_required": True,
                        "target_section": "전체 수동 검토",
                        "original_text": "오프라인 모드",
                        "proposed_text": request.content,
                        "reason": f"인프라 연결 실패로 인한 임시 폴백: {str(e)}"
                    }
                ]
            },
            "markdown_report": f"[PoC Fallback] RAG 엔진 예외 발생: {str(e)}\n내용: {request.content[:100]}...",
            "status": "Partial Success (Fallback)"
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
