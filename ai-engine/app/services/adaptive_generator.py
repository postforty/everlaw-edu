from typing import List, TypedDict
from pydantic import BaseModel, Field
from langchain_core.prompts import ChatPromptTemplate
from langgraph.graph import StateGraph, START, END
from app.core.config import llm
from app.core.database import get_retriever
from app.services.generator import QuizGeneration
from app.services.validator import ContentValidation, validate

class AdaptiveAgentState(TypedDict):
    law_reference: str             # 타겟 법령 (검색 쿼리용)
    previous_questions: List[str]  # 이전 문제 지문들 (제외용)
    context: List[str]             # RAG 결과
    generation_result: dict
    validation_result: dict
    answer: str

async def retrieve_law(state: AdaptiveAgentState):
    print(f"---RETRIEVING LAW FOR ADAPTIVE QUIZ: {state['law_reference']}---")
    retriever = get_retriever()
    documents = await retriever.ainvoke(state["law_reference"])
    context = [doc.page_content for doc in documents]
    if not context:
        context = [state["law_reference"]]
    return {"context": context}

async def generate_adaptive(state: AdaptiveAgentState):
    print("---GENERATING ADAPTIVE QUIZ CONTENT---")
    law_context_str = "\n\n".join(state.get("context", []))
    previous_questions_str = "\n".join([f"- {q}" for q in state.get("previous_questions", [])])
    if not previous_questions_str:
        previous_questions_str = "없음 (첫 출제입니다)"

    structured_llm = llm.with_structured_output(QuizGeneration)
    
    template = """당신은 법률 및 기업 컴플라이언스 교육 전문 AI 에이전트입니다.
    제공된 [법령 팩트 (Ground Truth)]를 근거로, 학습자의 취약점을 극복하기 위한 새로운 변형 퀴즈를 출제하세요.
    
    [법령 팩트 (Ground Truth)]
    {law_context}
    
    [이전에 출제되었던 문제들 (반드시 제외)]
    {previous_questions}
    
    [변형 퀴즈 출제 가이드라인]
    1. **절대 중복 금지**: [이전에 출제되었던 문제들]과 상황, 가상 인물(예: 김 대리 등), 질문의 관점이 겹치지 않도록 **완전히 새로운 시나리오**를 창작하세요.
    2. **명확한 정답과 매력적인 오답**: 4개의 객관식 보기 중 정답은 오직 1개이며, 나머지는 헷갈리기 쉬운 오답으로 구성하세요.
    3. **친절한 힌트와 상세한 해설**: 힌트와 해설을 작성하세요.
    4. **구조화된 출력**: 반드시 `QuizGeneration` 스키마 규격에 맞춰 JSON 데이터로 출력하세요.
    """
    
    prompt = ChatPromptTemplate.from_messages([
        ("system", template),
        ("human", "위 가이드라인에 따라 제공된 법령 팩트에 근거하여 완전히 새로운 실무 스토리텔링형 변형 퀴즈를 출제해주세요.")
    ])
    chain = prompt | structured_llm
    
    try:
        result: QuizGeneration = await chain.ainvoke({
            "law_context": law_context_str,
            "previous_questions": previous_questions_str
        })
        result_dict = result.dict()
    except Exception as e:
        print(f"Adaptive Generation Failed: {e}")
        # fallback
        result_dict = {
            "title": "Fallback",
            "law_reference": state["law_reference"],
            "quiz_question": "오류 발생으로 인한 대체 퀴즈입니다. 규정을 준수해야 합니까?",
            "quiz_options": ["예", "아니오", "모름", "상관없음"],
            "quiz_answer_index": 0,
            "quiz_hint": "준수",
            "quiz_explanation": "준수"
        }
    
    return {"generation_result": result_dict, "answer": "변형 퀴즈 생성 완료"}

def build_adaptive_graph():
    workflow = StateGraph(AdaptiveAgentState)
    workflow.add_node("retrieve", retrieve_law)
    workflow.add_node("generate", generate_adaptive)
    # Reuse validator.py's validate function, but we need to map state properties
    # Wait, validator.py expects 'context', 'generation_result', 'answer'. It perfectly matches.
    workflow.add_node("validate", validate)
    
    workflow.add_edge(START, "retrieve")
    workflow.add_edge("retrieve", "generate")
    workflow.add_edge("generate", "validate")
    workflow.add_edge("validate", END)
    
    return workflow.compile()

adaptive_graph = build_adaptive_graph()

async def generate_adaptive_quiz_async(law_reference: str, previous_questions: list[str]) -> dict:
    state = {
        "law_reference": law_reference,
        "previous_questions": previous_questions
    }
    final_state = await adaptive_graph.ainvoke(state)
    return {
        "generation_result": final_state["generation_result"],
        "validation_result": final_state["validation_result"]
    }
