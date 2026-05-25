from pydantic import BaseModel, Field
from langchain_core.prompts import ChatPromptTemplate
from app.core.config import llm
from app.services.generator import AgentState

# =====================================================================
# Pydantic Structured Output Schema (Pivot to Content Validation)
# =====================================================================

class ContentValidation(BaseModel):
    is_valid: bool = Field(description="생산된 강의 본문과 퀴즈가 RAG에서 추출해온 최신 법령 원본 팩트(수치, 법적 의도)를 단 1%의 왜곡도 없이 정확하게 반영하고 있으며 안전한지 여부")
    hallucination_score: float = Field(description="환각 의심 지수 (0.0~1.0 사이, 0.0에 가까울수록 안전하고 정확함)")
    validation_details: str = Field(description="최신 법령 조문 팩트와 생성된 마크다운 강의안 간의 1대1 교차 사실 대조(Fact-checking) 결과에 대한 상세 감사 소견")
    warning_flag: bool = Field(description="법령의 핵심 수치(숫자, 기한)가 원본과 불일치하여 즉시 관리자 경고(Red Flag)를 띄워야 하는지 여부")

async def validate(state: AgentState):
    """생산된 콘텐츠 내의 모든 수치와 의도가 RAG 원본 팩트와 정확하게 일치하는지 교차 사실 대조 감사 수행"""
    print("---VALIDATING GENERATED CONTENT (REFACTORED)---")
    context = state.get("context", [])
    gen_result = state.get("generation_result", {})
    report = state.get("answer", "")
    
    if not context or not gen_result:
        val_dict = {
            "is_valid": True,
            "hallucination_score": 0.0,
            "validation_details": "비교 및 검증할 원본 RAG 법령 팩트가 없어 감사 절차를 스킵합니다.",
            "warning_flag": False
        }
        return {"validation_result": val_dict, "answer": report}
        
    law_context_str = "\n\n".join(context)
    structured_llm = llm.with_structured_output(ContentValidation)
    
    template = """당신은 법률 컴플라이언스 전문 감사(Audit) AI 에이전트입니다.
    RAG에서 추출한 [원본 법령 원천 데이터]와 AI가 무에서 유로 새롭게 창작한 [생산된 퀴즈]를 철저히 교차 대조하여 사실 관계 확인(Fact-checking)을 수행하십시오.
    
    [원본 법령 원천 데이터 (Ground Truth)]
    {original_law}
    
    [생산된 퀴즈]
    강의 제목: {title}
    근거 참조 조항: {law_reference}
    생산 퀴즈:
    {quiz_proposed}
    
    다음 감사 기준에 따라 분석하여 결과를 정형 형태로 반환하십시오:
    1. 퀴즈의 지문, 힌트, 정답, 해설에 기술된 중요 규제 수치(예: 높이 2m, 과태료 벌금 수치 등)가 원본 법령의 수치와 단 1%의 오차도 없이 완벽하게 일치하는가? (숫자 불일치는 치명적 환각입니다)
    2. 생성된 퀴즈가 원본 법령의 의무 의도를 왜곡하거나, 임의로 지어낸 허위 사실(환각)을 포함하고 있지는 않은가?
    3. 환각 의심 지수(Hallucination Score)를 0.0~1.0 사이로 계산하십시오 (환각이 없을수록 0.0에 수렴함).
    4. 퀴즈의 핵심 수치(숫자, 기한)가 원본과 불일치하여 즉시 관리자 경고(Red Flag)를 띄워야 하는지 여부
    """
    
    prompt = ChatPromptTemplate.from_template(template)
    chain = prompt | structured_llm
    
    try:
        val_res: ContentValidation = await chain.ainvoke({
            "original_law": law_context_str,
            "title": gen_result.get("title", "N/A"),
            "law_reference": gen_result.get("law_reference", "N/A"),
            "quiz_proposed": gen_result.get("quiz_proposed", "N/A")
        })
        val_dict = val_res.dict()
    except Exception as e:
        print(f"Validation Node Failed: {e}")
        val_dict = {
            "is_valid": False,
            "hallucination_score": 0.8,
            "validation_details": f"자가 감사 엔진 기동 에러 발생: {str(e)}",
            "warning_flag": True
        }
        
    # 보고서 하단에 AI 자가 검증(Fact-checking) 감사 로그 렌더링
    report += f"\n---\n### 🛡️ 🤖 AI 자가 검증 시스템 감사 결과 (Auto-Validation Audit)\n"
    report += f"*   **검증 적합성 상태**: {'🟢 적합 (PASS)' if val_dict['is_valid'] else '🔴 보완 및 수동 검토 권장 (FAIL)'}\n"
    report += f"*   **환각 위험 지수 (Hallucination Score)**: `{val_dict['hallucination_score'] * 100:.1f}%` (낮을수록 안전)\n"
    report += f"*   **상세 감사 소견**: {val_dict['validation_details']}\n"
    
    if val_dict['warning_flag'] or val_dict['hallucination_score'] > 0.3:
        report += f"*   **⚠️ 수동 검토 권고 경고**: **활성화** (원본 법령 수치 혹은 조항 불일치 감지)\n"
    else:
        report += f"*   **⚠️ 수동 검토 권고 경고**: 비활성화 (법령 왜곡이 발견되지 않음)\n"
        
    return {"validation_result": val_dict, "answer": report}
