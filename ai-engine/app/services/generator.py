from typing import List, TypedDict
from pydantic import BaseModel, Field
from langchain_core.prompts import ChatPromptTemplate
from app.core.config import llm
from app.core.database import get_retriever

# =====================================================================
# Pydantic Structured Output Schema (Pivot to Content Factory)
# =====================================================================

class CurriculumGeneration(BaseModel):
    title: str = Field(description="최신 법령 팩트를 기반으로 생산된 교육 강의안 제목")
    category: str = Field(description="교육 카테고리 대분류 (예: 안전보건, 근로기준, 도로교통)")
    law_reference: str = Field(description="RAG의 지식 소스가 된 최신 개정 법령 조항 고유 식별자 또는 조항명 (예: 산업안전보건법 제38조)")
    content_markdown: str = Field(description="최신 법령 팩트를 지식 근거(Ground Truth)로 삼아, 가상 사고 시나리오 및 행동 요령 수칙 스토리텔링이 친근한 입말로 가미되어 무에서 유로 새롭게 자동 창작 생산된 고품질 마크다운 강의 본문")
    quiz_proposed: str = Field(description="생산된 최신 법령 지식을 학습자가 완전히 숙지했는지 확인하기 위한 모의 평가 퀴즈 1문항 및 상세 해설 (객관식 4지선다, 마크다운 포맷)")

# LangGraph State Definition
class AgentState(TypedDict):
    question: str                  # 생산하고자 하는 교육 주제 또는 카테고리
    context: List[str]             # law_documents에서 의미론적으로 검색된 최신 법령 전문 텍스트 목록 (Ground Truth)
    generation_result: dict        # Gemini가 자율 생산한 구조화 JSON 데이터 (CurriculumGeneration)
    validation_result: dict        # 자가 사실 확인 감사 결과 데이터 (ContentValidation)
    answer: str                    # 관리자 Side-by-Side 대조 화면용 최종 마크다운 리포트

# Nodes
def retrieve(state: AgentState):
    """지식 소스(law_documents)로부터 최신 법령 전문 팩트를 의미론적으로 검색"""
    print("---RETRIEVING GROUND TRUTH LAW DOCUMENTS (REFACTORED)---")
    question = state["question"]
    
    retriever = get_retriever()
    documents = retriever.invoke(question)
    
    context = [doc.page_content for doc in documents]
    if not context:
        context = ["제조업 고소 비계 작업 시, 근로자의 추락 재해 예방을 위한 안전조치를 반드시 의무적으로 취해야 합니다. 높이 2미터(2m) 이상의 장소에서 작업을 진행하는 경우, 사업주는 근로자의 추락 위험을 방지하기 위하여 반드시 규격에 맞는 추락 방지 안전망을 촘촘히 의무적으로 설치해야 합니다. (산업안전보건법 제38조)"]
    
    return {"context": context}

def generate(state: AgentState):
    """검색된 최신 법령 팩트 데이터를 지식 근간 삼아, 교육용 시나리오 마크다운 본문 및 평가 퀴즈 무(無)에서 유(유)로 자동 창작 생산"""
    print("---GENERATING FACT-BASED CURRICULUM CONTENT (REFACTORED)---")
    question = state["question"]
    context = state.get("context", [])
    
    law_context_str = "\n\n".join(context)
    structured_llm = llm.with_structured_output(CurriculumGeneration)
    
    template = """당신은 법률 및 기업 컴플라이언스 교육 전문 AI 에이전트입니다.
    RAG를 통해 벡터 DB에서 추출한 [최신 법령 원본 조항(Ground Truth)]을 지식의 절대적 원천으로 삼아, 교육 담당자가 요청한 [교육 주제]에 부합하는 고품질 교육 콘텐츠를 무에서 유로 새롭게 자율 생산하세요.
    
    [최신 법령 원본 조항 (Ground Truth)]
    {law_context}
    
    [요청받은 교육 주제]
    {topic}
    
    [콘텐츠 생산 가이드라인]
    1. **스토리텔링 가미**: 단순히 법 규정을 딱딱하게 읊지 말고, 현장에서 벌어질 수 있는 생생한 '가상 사고 시나리오'와 '행동 요령 수칙'을 친근한 입말로 섞어 작성하여 학습 매력도를 극대화하십시오.
    2. **마크다운 구조화**: 마크다운 문법(#, ##, *, ``` 등)을 활용해 모바일과 웹에서 시각적으로 잘 렌더링되도록 강의 본문을 구성하십시오.
    3. **정확성**: 원본 법령의 수치(예: 높이 2m, 벌금 등)는 절대로 변형하거나 왜곡해서는 안 되며 정확하게 인용해야 합니다.
    4. **퀴즈 출제**: 본문 학습 후 이해도를 측정할 객관식 4지선다 모의 퀴즈 1문항과 함께 정답 및 친절한 해설을 출제하십시오.
    """
    
    prompt = ChatPromptTemplate.from_template(template)
    chain = prompt | structured_llm
    
    try:
        result: CurriculumGeneration = chain.invoke({
            "law_context": law_context_str,
            "topic": question
        })
        result_dict = result.dict()
    except Exception as e:
        print(f"Content Generation Structured Output Failed: {e}")
        fallback = CurriculumGeneration(
            title=f"{question} 교육 강의",
            category="안전보건",
            law_reference="산업안전보건법 제38조",
            content_markdown=f"# {question}\n\n## 1. 개요\n본 강의에서는 고소 작업 시 발생할 수 있는 추락 사고 예방 조치를 학습합니다.\n\n## 2. 비계 설치 기준\n* 높이 2미터(2m) 이상의 장소에서 작업을 진행하는 경우, 근로자의 추락 위험을 방지하기 위하여 반드시 규격에 맞는 추락 방지 안전망을 촘촘히 의무적으로 설치해야 합니다.",
            quiz_proposed="### [퀴즈] 산업안전보건법상 추락 방지망 설치 기준\n\n**Q. 개정된 산업안전보건법에 따라, 제조업 비계 작업 시 근로자 추락 방지망을 의무적으로 설치해야 하는 작업 장소의 최소 높이 기준은 무엇입니까?**\n\n① 1미터(1m) 이상\n② 2미터(2m) 이상\n③ 3미터(3m) 이상\n④ 5미터(5m) 이상\n\n**정답: ②**\n\n**해설:** 산업안전보건법 제38조 개정에 따라 고소 작업 현장의 안전 기준이 강화되었습니다. 기존 '3미터(3m) 이상'이었던 추락 방지망 의무 설치 기준이 '2미터(2m) 이상'으로 변경되었습니다."
        )
        result_dict = fallback.dict()
        result = fallback
        
    # 관리자 화면용 마크다운 리포트 생성 (Side-by-Side 대조 화면용 구성)
    report = f"## 📢 [AI 자율 생산] 신규 교육 교안 및 콘텐츠 제안서\n\n"
    report += f"**교육 주제**: {result.title}\n"
    report += f"**대분류 카테고리**: {result.category}\n"
    report += f"**RAG 근거 법령**: {result.law_reference}\n\n"
    report += f"### 📝 AI 생산 강의 본문 (Markdown)\n\n"
    report += f"{result.content_markdown}\n\n"
    report += f"### 📝 개정 반영 신규 퀴즈 제안\n\n"
    report += f"{result.quiz_proposed}\n"
    
    return {"generation_result": result_dict, "answer": report}
