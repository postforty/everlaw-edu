from typing import List, TypedDict
from pydantic import BaseModel, Field
from langchain_core.prompts import ChatPromptTemplate
from app.core.config import llm
from app.core.database import get_retriever, retrieve_affected_curriculum_async

# =====================================================================
# Pydantic Structured Output Schema (Pivot to Content Factory)
# =====================================================================

class QuizGeneration(BaseModel):
    title: str = Field(description="출제된 퀴즈의 핵심 주제 또는 법령 조항 (예: 산업안전보건법 제38조 비계 작업)")
    law_reference: str = Field(description="RAG의 지식 소스가 된 최신 법령 조항 고유 식별자 또는 조항명 (예: 산업안전보건법 제38조)")
    quiz_question: str = Field(description="법령 지식을 학습자가 완전히 숙지했는지 확인하기 위한 실무 현장 스토리텔링형 질문 본문")
    quiz_options: List[str] = Field(description="객관식 4지선다 보기 항목 4개 (문자열 배열)")
    quiz_answer_index: int = Field(description="정답 보기의 인덱스 (0부터 3 사이의 정수)")
    quiz_hint: str = Field(description="문제를 풀 때 도움이 되는 짧은 힌트")
    quiz_explanation: str = Field(description="문제에 대한 상세 법적 근거 및 해설")

# LangGraph State Definition
class AgentState(TypedDict):
    question: str                  # 생산하고자 하는 교육 주제 또는 법령 텍스트
    context: List[str]             # law_documents에서 의미론적으로 검색된 법령 전문 텍스트 목록 (Ground Truth)
    previous_questions: List[str]  # 중복 출제 방지를 위한 이전 퀴즈 지문 목록
    generation_result: dict        # Gemini가 자율 생산한 구조화 JSON 데이터 (QuizGeneration)
    validation_result: dict        # 자가 사실 확인 감사 결과 데이터 (ContentValidation)
    answer: str                    # 관리자 대조 화면용 퀴즈 마크다운 리포트

# Nodes
async def retrieve(state: AgentState):
    """지식 소스(law_documents)로부터 법령 전문 팩트를 의미론적으로 검색"""
    print("---RETRIEVING GROUND TRUTH LAW---")
    question = state["question"]
    
    # 1. 최신 법령 전문 팩트 검색
    retriever = get_retriever()
    documents = await retriever.ainvoke(question)
    context = [doc.page_content for doc in documents]
    
    # RAG 검색 결과가 없으면 원본 question 자체를 컨텍스트로 사용
    if not context:
        context = [question]

    return {"context": context}

async def generate(state: AgentState):
    """법령 팩트를 융합하여 실무 현장 스토리텔링형 4지선다 모의 퀴즈 자동 재생산"""
    print("---GENERATING QUIZ CONTENT---")
    question = state["question"]
    context = state.get("context", [])
    
    law_context_str = "\n\n".join(context)
    previous_questions_str = "\n".join([f"- {q}" for q in state.get("previous_questions", [])])
    if not previous_questions_str:
        previous_questions_str = "없음 (첫 출제입니다)"
    structured_llm = llm.with_structured_output(QuizGeneration)
    
    template = """당신은 법률 및 기업 컴플라이언스 교육 전문 AI 에이전트입니다.
    제공된 [법령 팩트 (Ground Truth)]만을 근거로 하여, 임직원들이 해당 법령을 완벽하게 숙지할 수 있도록 실무 현장 사례를 바탕으로 한 4지선다형 퀴즈를 1문항 출제해야 합니다.
    
    [법령 팩트 (Ground Truth)]
    {law_context}
    
    [이전에 출제되었던 문제들 (반드시 제외)]
    {previous_questions}
    
    [퀴즈 출제 가이드라인]
    1. **절대 중복 금지**: [이전에 출제되었던 문제들]과 상황, 가상 인물(예: 김 대리, 박 소장 등), 질문의 관점이 겹치지 않도록 **완전히 새로운 시나리오**를 창작하십시오.
    2. **명확한 정답과 매력적인 오답**: 4개의 객관식 보기 중 정답은 오직 1개이며, 나머지 3개는 법령을 헷갈리기 쉽게 만드는 매력적인 오답으로 구성하십시오.
    3. **친절한 힌트와 상세한 해설**: 학습자가 생각하도록 유도하는 힌트와, 정답 및 오답의 이유를 법적 근거에 기반하여 상세히 설명하는 해설을 작성하십시오.
    4. **구조화된 출력**: 반드시 `QuizGeneration` 스키마 규격에 맞춰 JSON 데이터로 출력하십시오.
    """
    
    prompt = ChatPromptTemplate.from_messages([
        ("system", template),
        ("human", "위 가이드라인에 따라 제공된 법령 팩트에 근거하여 완전히 새로운 실무 스토리텔링형 4지선다 퀴즈를 출제해주세요.")
    ])
    chain = prompt | structured_llm
    
    try:
        result: QuizGeneration = await chain.ainvoke({
            "law_context": law_context_str,
            "previous_questions": previous_questions_str
        })
        result_dict = result.dict()
    except Exception as e:
        print(f"Content Generation Structured Output Failed: {e}")
        fallback = QuizGeneration(
            title="법령 기반 컴플라이언스 퀴즈",
            law_reference="제공된 법령 데이터",
            quiz_question="다음 중 제공된 법령 규정에 따른 올바른 조치는 무엇입니까?",
            quiz_options=["관련 법령을 준수하지 않는다.", "법령에 규정된 의무 사항을 준수한다.", "임의로 안전 조치를 생략한다.", "비용 절감을 위해 필수 규정을 무시한다."],
            quiz_answer_index=1,
            quiz_hint="모든 임직원은 법령에 규정된 사항을 최우선으로 준수해야 합니다.",
            quiz_explanation="컴플라이언스의 핵심은 규정된 법적 의무를 철저히 지키는 것입니다."
        )
        result_dict = fallback.dict()
        result = fallback
        
    # 관리자 화면용 마크다운 퀴즈 리포트 생성
    report = f"## ⚖️ 신규 문제 은행 퀴즈 제안서\n\n"
    report += f"**퀴즈 주제**: {result.title}\n"
    report += f"**근거 법령**: {result.law_reference}\n\n"
    report += f"### 📝 문제\n\n"
    report += f"**Q. {result.quiz_question}**\n\n"
    for idx, opt in enumerate(result.quiz_options):
        report += f"{idx + 1}) {opt}\n"
    report += f"\n**정답:** {result.quiz_answer_index + 1}번\n"
    report += f"**힌트:** {result.quiz_hint}\n"
    report += f"**해설:** {result.quiz_explanation}\n"
    
    return {"generation_result": result_dict, "answer": report}
