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

@app.post("/analyze-impact")
async def analyze_impact(request: LawChangeRequest):
    # TODO: Implement Impact Analysis Logic
    return {
        "law_id": request.law_id,
        "impact_level": "High",
        "affected_modules": ["Module 1: Industrial Safety", "Module 3: Risk Assessment"]
    }

from rag_engine import generate_rag_content

@app.post("/generate-content")
async def generate_content(request: LawChangeRequest):
    try:
        # 실제 RAG 엔진 호출
        # 참고: 현재는 로컬 DB 및 Ollama가 실행 중이어야 정상 작동함
        result = generate_rag_content(request.content)
        return {
            "law_id": request.law_id,
            "generated_content": result,
            "status": "Success"
        }
    except Exception as e:
        # 인프라 미준비 시 예외 처리 (PoC 단계)
        return {
            "law_id": request.law_id,
            "generated_content": f"[PoC Fallback] 인프라 연결 실패: {str(e)}\n내용: {request.content[:50]}...",
            "status": "Partial Success (Fallback)"
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
