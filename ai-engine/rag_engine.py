import os
from typing import Annotated, TypedDict, List
from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_ollama import OllamaEmbeddings
from langchain_community.vectorstores import PGVector
from langchain_core.messages import BaseMessage, HumanMessage
from langchain_core.prompts import ChatPromptTemplate
from langgraph.graph import StateGraph, END

load_dotenv()

# Configuration
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL")
POSTGRES_URL = os.getenv("POSTGRES_URL")
LLM_MODEL = os.getenv("LLM_MODEL")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL")

# Initialize Models
embeddings = OllamaEmbeddings(
    base_url=OLLAMA_BASE_URL,
    model=EMBEDDING_MODEL
)

llm = ChatGoogleGenerativeAI(
    model=LLM_MODEL,
    google_api_key=GOOGLE_API_KEY,
    temperature=0
)

# Vector Store
CONNECTION_STRING = POSTGRES_URL
COLLECTION_NAME = "law_documents"
COLLECTION_NAME_CURRICULUM = "curriculum_documents"

def get_curriculum_retriever():
    vector_store = PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME_CURRICULUM,
    )
    return vector_store.as_retriever()

def get_retriever():
    vector_store = PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME,
    )
    return vector_store.as_retriever()

from langchain_core.documents import Document

def add_document_to_vector_store(text: str, metadata: dict):
    """추출된 개정 법령 텍스트를 pgvector에 임베딩 및 적재"""
    print("---ADDING DOCUMENT TO VECTOR STORE---")
    vector_store = PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME,
    )
    doc = Document(page_content=text, metadata=metadata)
    vector_store.add_documents([doc])
    print(f"Document successfully added with metadata: {metadata}")

def add_curriculum_to_vector_store(text: str, metadata: dict):
    """기존 교육 커리큘럼의 개별 강의안(Markdown)을 pgvector에 적재"""
    print("---ADDING CURRICULUM TO VECTOR STORE---")
    vector_store = PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME_CURRICULUM,
    )
    doc = Document(page_content=text, metadata=metadata)
    vector_store.add_documents([doc])
    print(f"Curriculum document added: {metadata.get('title', 'Untitled')}")

def retrieve_affected_curriculum(law_content: str) -> List[dict]:
    """개정 법령 텍스트를 기준으로 가장 유사도 높은(영향을 받을 가능성이 큰) 기존 커리큘럼 강의안들을 검색"""
    print("---RETRIEVING AFFECTED CURRICULUM---")
    retriever = get_curriculum_retriever()
    documents = retriever.invoke(law_content)
    
    affected_lessons = []
    for doc in documents:
        affected_lessons.append({
            "lesson_id": doc.metadata.get("lesson_id"),
            "curriculum_id": doc.metadata.get("curriculum_id"),
            "title": doc.metadata.get("title", "Unknown Lesson"),
            "content": doc.page_content
        })
    return affected_lessons

from pydantic import BaseModel, Field
from typing import List, Optional

# Pydantic Structured Output Schema
class SectionModification(BaseModel):
    is_modification_required: bool = Field(description="기존 강의안에 법령 개정으로 인한 수정이 필요한지 여부")
    target_section: Optional[str] = Field(description="수정이 필요한 기존 강의안의 섹션명 또는 단락 제목")
    original_text: Optional[str] = Field(description="수정해야 할 기존 강의안의 원본 텍스트 구절 (정확하게 일치해야 함)")
    proposed_text: Optional[str] = Field(description="새로 개정된 법령을 완벽하게 반영하여 수정한 제안 텍스트")
    reason: Optional[str] = Field(description="이 섹션을 수정해야 하는 구체적인 법적 사유 및 변경 내용 설명")

class LessonImpactAnalysis(BaseModel):
    lesson_id: int = Field(description="영향을 받는 기존 강의 ID")
    title: str = Field(description="강의 제목")
    impact_level: str = Field(description="영향도 등급 (High, Medium, Low)")
    modifications: List[SectionModification] = Field(description="단락별 세부 수정 제안 내역 목록")
    quiz_proposed: Optional[str] = Field(description="개정 법령을 반영하여 새롭게 제안하는 모의 퀴즈 문제 및 상세 해설 (마크다운 포맷)")

class ContentValidation(BaseModel):
    is_valid: bool = Field(description="제안된 수정안이 원본 개정 법령의 취지를 훼손하거나 왜곡하지 않고 정확하게 반영하는지 여부")
    hallucination_score: float = Field(description="환각 의심 지수 (0.0~1.0 사이, 0.0에 가까울수록 안전하고 정확함)")
    validation_details: str = Field(description="사실 관계 확인(Fact-checking) 결과에 대한 상세 기술 및 문제점 지적")
    warning_flag: bool = Field(description="치명적인 오류나 왜곡이 의심되어 즉각 수동 검토 경고를 띄워야 하는지 여부")

# LangGraph State Definition
class AgentState(TypedDict):
    question: str                  # 개정 법령 원문
    context: List[str]             # (기존 노드 호환용)
    affected_lessons: List[dict]   # pgvector에서 조회된 연관 기존 강의 목록
    analysis_result: dict          # Gemini가 분석한 JSON 구조 데이터 (LessonImpactAnalysis)
    validation_result: dict        # 자가 검증 결과 데이터 (ContentValidation)
    answer: str                    # 마크다운 형태의 최종 보고서

# Nodes
def retrieve(state: AgentState):
    print("---RETRIEVING---")
    question = state["question"]
    
    # 개정 법령과 가장 연관이 깊은 기존 커리큘럼(강의안) 목록 검색
    affected = retrieve_affected_curriculum(question)
    context = [l["content"] for l in affected]
    
    return {"context": context, "affected_lessons": affected}

def generate(state: AgentState):
    print("---GENERATING IMPACT ANALYSIS AND PROPOSED CONTENT---")
    question = state["question"]
    affected_lessons = state.get("affected_lessons", [])
    
    if not affected_lessons:
        # 연관된 커리큘럼이 전혀 없을 때의 예외 처리
        empty_analysis = {
            "lesson_id": -1,
            "title": "N/A",
            "impact_level": "Low",
            "modifications": [],
            "quiz_proposed": "영향을 받는 커리큘럼이 없어 퀴즈가 생성되지 않았습니다."
        }
        no_match_text = "개정 법령과 직접적인 연관성이 식별된 기존 교육 커리큘럼이 없습니다. 수정안을 제안하지 않습니다."
        return {"analysis_result": empty_analysis, "answer": no_match_text}
        
    # 가장 연관도가 높은 첫 번째 강의안을 대상으로 정밀 차분 분석 수행
    target_lesson = affected_lessons[0]
    
    # Gemini 구조화 모델 호출 모델 정의
    structured_llm = llm.with_structured_output(LessonImpactAnalysis)
    
    template = """당신은 법률 및 기업 컴플라이언스 교육 전문 AI 에이전트입니다. 
    새롭게 개정된 법령 정보(개정 법령)를 바탕으로 기존 교육 강의안(기존 교안)의 내용을 엄밀히 분석하여 수정 제안서(Gap Analysis)를 생성하고 퀴즈를 출제하세요.
    
    [개정 법령]
    {law_content}
    
    [기존 교안 (강의명: {lesson_title})]
    {lesson_content}
    
    반드시 주어진 기존 교안 내의 텍스트와 개정 법령을 상세 비교하여, 개정 법령이 실질적으로 강의 내용의 수정(수치 변경, 의무 조항 추가 등)을 요구하는지 철저하게 판별하세요.
    만약 수정이 필요하다면 기존 교안에서 일치하는 원본 구절(original_text)을 추출하고, 완벽하게 정정된 제안 텍스트(proposed_text)와 법적 근거를 바탕으로 한 수정 사유(reason)를 상세히 서술하세요.
    마지막으로 개정된 법령 내용을 학습자가 제대로 이해했는지 확인하기 위한 모의 퀴즈 1문항(객관식 4지선다, 정답 및 해설 포함, 마크다운 형식)을 출제하여 quiz_proposed 필드에 담아주세요.
    """
    
    prompt = ChatPromptTemplate.from_template(template)
    chain = prompt | structured_llm
    
    # Gemini 차분 분석 호출
    try:
        result: LessonImpactAnalysis = chain.invoke({
            "law_content": question,
            "lesson_title": target_lesson["title"],
            "lesson_content": target_lesson["content"]
        })
        result_dict = result.dict()
    except Exception as e:
        print(f"Structured Output Generation Failed: {e}")
        # 실패 시 예외 처리 구조 구성
        fallback = LessonImpactAnalysis(
            lesson_id=target_lesson.get("lesson_id", -1),
            title=target_lesson["title"],
            impact_level="Medium (Error Fallback)",
            modifications=[
                SectionModification(
                    is_modification_required=True,
                    target_section="전체 내용 대조",
                    original_text="교안 원본 확인 중",
                    proposed_text=f"[개정 법령 내용 적용 필요]\n{question}",
                    reason="구조화 파싱 실패로 인한 수동 검토 권장"
                )
            ],
            quiz_proposed="### [퀴즈 임시생성]\n개정된 법령이 올바르게 교육 콘텐츠에 적용되었는지 확인하세요."
        )
        result_dict = fallback.dict()
        result = fallback
    
    # lesson_id 보정 (실제 벡터 DB 메타데이터의 lesson_id와 바인딩)
    result_dict["lesson_id"] = target_lesson.get("lesson_id", -1)
    
    # 관리자 Side-by-Side UI 표기용 마크다운 리포트 생성
    report = f"## 📢 법령 개정에 따른 교안 수정 제안서\n\n"
    report += f"**대상 강의**: {target_lesson['title']} (ID: {target_lesson.get('lesson_id')})\n"
    report += f"**영향도 등급**: {result.impact_level}\n\n"
    report += f"### 🔄 세부 수정 필요 내역\n\n"
    
    for idx, mod in enumerate(result.modifications, 1):
        if mod.is_modification_required:
            report += f"#### [{idx}] 섹션: {mod.target_section}\n"
            report += f"*   **수정 사유**: {mod.reason}\n"
            report += f"*   **기존 내용 (Before)**:\n    ```text\n    {mod.original_text}\n    ```\n"
            report += f"*   **제안 내용 (After)**:\n    ```markdown\n    {mod.proposed_text}\n    ```\n\n"
        else:
            report += f"#### [{idx}] 섹션: {mod.target_section} -> **수정 불필요 (법령 부합)**\n\n"
            
    report += f"### 📝 개정 반영 신규 퀴즈 제안\n{result.quiz_proposed}\n"
    
    return {"analysis_result": result_dict, "answer": report}

def validate(state: AgentState):
    print("---VALIDATING GENERATED CONTENT---")
    question = state["question"]
    analysis = state.get("analysis_result", {})
    report = state.get("answer", "")
    
    if not analysis or analysis.get("lesson_id") == -1:
        # 수정 사항이 없거나 폴백 상황일 경우 검증 패스
        val_dict = {
            "is_valid": True,
            "hallucination_score": 0.0,
            "validation_details": "비교 및 검증할 수정안이 감지되지 않아 검증 절차를 생기합니다.",
            "warning_flag": False
        }
        return {"validation_result": val_dict, "answer": report}
        
    # 검증용 체인 준비
    structured_llm = llm.with_structured_output(ContentValidation)
    
    template = """당신은 법률 컴플라이언스 전문 감사(Audit) AI 에이전트입니다. 
    제안된 [수정안 내용]이 [원본 개정 법령]의 취지를 왜곡하거나 환각(Hallucination) 현상을 보이지 않는지 엄격히 사실 관계 확인(Fact-checking)을 수행하세요.
    
    [원본 개정 법령]
    {original_law}
    
    [수정안 내용 (강의명: {lesson_title})]
    {modifications}
    
    다음 기준을 바탕으로 분석하여 결과를 정형 형태로 반환하십시오:
    1. 제안된 수정 문구(proposed_text)가 원본 법령의 의무 조항이나 중요 규정을 생략/약화시키지 않았는가?
    2. 중요 수치(예: 높이 2m 이상, 벌금 5천만원 등)가 왜곡되지 않고 정확히 들어갔는가?
    3. 법령 해석의 환각이 의심되어 즉각적인 수동 검토가 필요합니까? (의심 지수를 0.0~1.0 사이로 산출. 위험할수록 1.0에 가까움)
    """
    
    # 수정 내역 요약 조립
    mods_str = ""
    for idx, mod in enumerate(analysis.get("modifications", []), 1):
        if mod.get("is_modification_required"):
            mods_str += f"[{idx}] 섹션: {mod.get('target_section')}\n"
            mods_str += f"- 원본: {mod.get('original_text')}\n"
            mods_str += f"- 제안: {mod.get('proposed_text')}\n"
            mods_str += f"- 사유: {mod.get('reason')}\n\n"
            
    prompt = ChatPromptTemplate.from_template(template)
    chain = prompt | structured_llm
    
    try:
        val_res: ContentValidation = chain.invoke({
            "original_law": question,
            "lesson_title": analysis.get("title", "Unknown"),
            "modifications": mods_str or "수정 내역 없음"
        })
        val_dict = val_res.dict()
    except Exception as e:
        print(f"Validation Node Failed: {e}")
        val_dict = {
            "is_valid": False,
            "hallucination_score": 0.8,
            "validation_details": f"감사 노드 구동 중 에러 발생: {str(e)}",
            "warning_flag": True
        }
    
    # 보고서 하단에 AI 자가 검증(Fact-checking) 감사 로그 렌더링
    report += f"\n---\n### 🛡️ 🤖 AI 자가 검증 시스템 감사 결과 (Auto-Validation Audit)\n"
    report += f"*   **검증 적합성 상태**: {'🟢 적합 (PASS)' if val_dict['is_valid'] else '🔴 보완 및 수동 검토 권장 (FAIL)'}\n"
    report += f"*   **환각 위험 지수 (Hallucination Score)**: `{val_dict['hallucination_score'] * 100:.1f}%` (낮을수록 안전)\n"
    report += f"*   **상세 감사 소견**: {val_dict['validation_details']}\n"
    
    if val_dict['warning_flag']:
        report += f"*   **⚠️ 수동 검토 권고 경고**: **활성화** (수치 혹은 규정 불일치 의심)\n"
    else:
        report += f"*   **⚠️ 수동 검토 권고 경고**: 비활성화 (법령 왜곡이 발견되지 않음)\n"
        
    return {"validation_result": val_dict, "answer": report}

# Graph Construction
workflow = StateGraph(AgentState)

# Add Nodes
workflow.add_node("retrieve", retrieve)
workflow.add_node("generate", generate)
workflow.add_node("validate", validate)

# Set Entry Point and Edges
workflow.set_entry_point("retrieve")
workflow.add_edge("retrieve", "generate")
workflow.add_edge("generate", "validate")
workflow.add_edge("validate", END)

# Compile Graph
app = workflow.compile()

def generate_rag_content(question: str) -> dict:
    # Execute Graph
    inputs = {"question": question}
    result = app.invoke(inputs)
    return {
        "analysis_result": result.get("analysis_result"),
        "validation_result": result.get("validation_result"),
        "markdown_report": result.get("answer")
    }
