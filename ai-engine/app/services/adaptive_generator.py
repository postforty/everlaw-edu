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
    
    # 1. Try exact match first using SQL to prevent Hallucination (Semantic search might return wrong articles)
    try:
        from app.core.database import engine
        from sqlalchemy import text as sql_text
        with engine.connect() as conn:
            query = sql_text("""
                SELECT document 
                FROM langchain_pg_embedding
                WHERE 
                   (cmetadata->>'law_name') || 
                   CASE WHEN cmetadata->>'law_type' IS NOT NULL AND cmetadata->>'law_type' != '법률' THEN ' ' || (cmetadata->>'law_type') ELSE '' END ||
                   CASE WHEN (cmetadata->>'Header 2' LIKE '%부칙%') OR (cmetadata->>'Header 1' LIKE '%부칙%') THEN ' 부칙' ELSE '' END ||
                   ' ' || (cmetadata->>'article') = :law_ref
                LIMIT 3
            """)
            result = conn.execute(query, {"law_ref": state["law_reference"]}).fetchall()
            if result:
                print(f"Exact match found in DB for {state['law_reference']}.")
                return {"context": [row[0] for row in result]}
    except Exception as e:
        print(f"Exact match query failed: {e}")

    # 2. Fallback to semantic search if exact match fails or for extra context
    print("Falling back to semantic search...")
    retriever = get_retriever()
    documents = await retriever.ainvoke(state["law_reference"])
    context = [doc.page_content for doc in documents]
    if not context:
        context = [state["law_reference"]]
        
    # 3. 다중 홉(Multi-hop) 검색: 참조된 별표 탐지 (Top 1 문서에서만 추출하여 불필요한 별표 폭탄 방지)
    import re
    top_doc_content = documents[0].page_content if documents else state["law_reference"]
    references = list(set(re.findall(r'별표\s*\d+', top_doc_content)))
    
    if references:
        # 최대 2개의 별표만 검색 (토큰 제한 및 환각 방지)
        references = references[:2]
        print(f"---MULTI-HOP RETRIEVAL: Found references {references}---")
        # 법령 이름 추출 (예: "산업안전보건법 제24조제1항" -> "산업안전보건법")
        law_name_match = re.match(r'([^\s제]+)', state["law_reference"])
        law_name = law_name_match.group(1) if law_name_match else "법령"
        
        for ref in references:
            # 2차 검색 쿼리 구성 (예: "산업안전보건법 시행령 별표 9")
            secondary_query = f"{law_name} 시행령 {ref}"
            print(f"Secondary Query: {secondary_query}")
            extra_docs = await retriever.ainvoke(secondary_query)
            # 2차 검색 결과를 컨텍스트에 추가
            context.extend([doc.page_content for doc in extra_docs[:2]])

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
    1. **절대 중복 금지**: [이전에 출제되었던 문제들]과 완벽히 차별화된 **새로운 실무 시나리오(새로운 인물, 새로운 업종, 새로운 상황)**를 창작하십시오.
    2. **난이도 및 함정**: 정답은 명확하되, 오답은 실무자가 현장에서 흔히 착각하는 법적 오해(함정)를 포함하여 난이도를 높이십시오.
    3. **메타 질문 절대 금지**: "어느 조항인가?", "어떤 별표인가?", "어떤 법적 근거를 참조해야 하는가?" 등의 메타 질문은 금지하며, 법령의 '구체적인 핵심 내용'을 물어보십시오.
    4. **위임/참조 조항 처리 및 수치 활용**: 제공된 [법령 팩트] 내에 구체적인 수치 데이터(예: 50명, 100명 등)가 있다면 반드시 이를 활용하여 실무적인 시나리오를 구성하십시오. 만약 구체적 수치가 없고 단순히 "별표에 따른다"는 문구만 있다면, 법적 근거 명칭을 묻지 말고 법령 본문에 명시된 **가장 핵심적인 원칙이나 목적(예: "근로자와 사용자가 같은 수로 구성해야 한다")**을 묻는 문제를 출제하십시오.
    5. **친절한 해설**: 정답과 오답의 이유를 법적 근거에 기반하여 명확히 해설하십시오.
    6. **구조화된 JSON 출력**: 반드시 `QuizGeneration` 스키마 규격에 맞춰 출력하십시오.
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
