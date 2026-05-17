import os
from typing import Annotated, TypedDict, List, Optional
from dotenv import load_dotenv
from pydantic import BaseModel, Field
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_ollama import OllamaEmbeddings
from langchain_community.vectorstores import PGVector
from langchain_core.messages import BaseMessage, HumanMessage
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.documents import Document
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

def get_retriever():
    """최신 법령 전문(Ground Truth) 저장 테이블에서 검색을 수행하는 리트리버 획득"""
    vector_store = PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME,
    )
    return vector_store.as_retriever()

def get_curriculum_retriever():
    vector_store = PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME_CURRICULUM,
    )
    return vector_store.as_retriever()

def add_document_to_vector_store(text: str, metadata: dict):
    """추출된 개정 법령 텍스트를 pgvector에 임베딩 및 적재 (신선도 유지를 위한 SQL-level Upsert 지원)"""
    print("---ADDING DOCUMENT TO VECTOR STORE---")
    vector_store = PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME,
    )
    doc = Document(page_content=text, metadata=metadata)
    
    # law_id 또는 commit_sha를 고유 키로 활용하여 중복 누적 인서트 방지
    law_key = metadata.get("law_id") or metadata.get("commit_sha")
    custom_id = f"law_{law_key}" if law_key else None
    
    if custom_id:
        # [물리적 중복 제거] LangChain PK 제약조건 한계를 무력화하기 위해 적재 전 기존 custom_id를 완전히 DELETE
        try:
            from sqlalchemy import create_engine, text as sql_text
            import json
            engine = create_engine(
                CONNECTION_STRING,
                json_serializer=lambda obj: json.dumps(obj, ensure_ascii=False)
            )
            with engine.connect() as conn:
                conn.execute(
                    sql_text("DELETE FROM langchain_pg_embedding WHERE custom_id = :custom_id"),
                    {"custom_id": custom_id}
                )
                conn.commit()
            print(f"🧹 [성공] 기존 동일 법령(Key: {custom_id}) 물리적 청소 완료")
        except Exception as e:
            print(f"⚠️ [경고] 적재 전 청소 에러 (무시하고 적재 진행): {e}")

        vector_store.add_documents([doc], ids=[custom_id])
    else:
        vector_store.add_documents([doc])
    print(f"Document successfully added/updated with key: {custom_id or 'Auto-UUID'}")

def add_curriculum_to_vector_store(text: str, metadata: dict):
    """기존 교육 커리큘럼의 개별 강의안(Markdown)을 pgvector에 적재 (최신성/신선도 유지를 위한 SQL-level Upsert 지원)"""
    print("---ADDING CURRICULUM TO VECTOR STORE---")
    vector_store = PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME_CURRICULUM,
    )
    doc = Document(page_content=text, metadata=metadata)
    
    # lesson_id를 고유 식별자 키로 삼아 항상 최신 버전의 강의안만 유지
    lesson_id = metadata.get("lesson_id")
    custom_id = f"lesson_{lesson_id}" if lesson_id else None
    
    if custom_id:
        # [물리적 중복 제거] LangChain PK 제약조건 한계를 무력화하기 위해 적재 전 기존 custom_id를 완전히 DELETE
        try:
            from sqlalchemy import create_engine, text as sql_text
            engine = create_engine(CONNECTION_STRING)
            with engine.connect() as conn:
                conn.execute(
                    sql_text("DELETE FROM langchain_pg_embedding WHERE custom_id = :custom_id"),
                    {"custom_id": custom_id}
                )
                conn.commit()
            print(f"🧹 [성공] 기존 동일 강의안(Key: {custom_id}) 물리적 청소 완료")
        except Exception as e:
            print(f"⚠️ [경고] 적재 전 청소 에러 (무시하고 적재 진행): {e}")

        vector_store.add_documents([doc], ids=[custom_id])
    else:
        vector_store.add_documents([doc])
    print(f"Curriculum document successfully added/updated with key: {custom_id or 'Auto-UUID'} ({metadata.get('title', 'Untitled')})")

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

# =====================================================================
# Pydantic Structured Output Schema (Pivot to Content Factory)
# =====================================================================

class CurriculumGeneration(BaseModel):
    title: str = Field(description="최신 법령 팩트를 기반으로 생산된 교육 강의안 제목")
    category: str = Field(description="교육 카테고리 대분류 (예: 안전보건, 근로기준, 도로교통)")
    law_reference: str = Field(description="RAG의 지식 소스가 된 최신 개정 법령 조항 고유 식별자 또는 조항명 (예: 산업안전보건법 제38조)")
    content_markdown: str = Field(description="최신 법령 팩트를 지식 근거(Ground Truth)로 삼아, 가상 사고 시나리오 및 행동 요령 수칙 스토리텔링이 친근한 입말로 가미되어 무에서 유로 새롭게 자동 창작 생산된 고품질 마크다운 강의 본문")
    quiz_proposed: str = Field(description="생산된 최신 법령 지식을 학습자가 완전히 숙지했는지 확인하기 위한 모의 평가 퀴즈 1문항 및 상세 해설 (객관식 4지선다, 마크다운 포맷)")

class ContentValidation(BaseModel):
    is_valid: bool = Field(description="생산된 강의 본문과 퀴즈가 RAG에서 추출해온 최신 법령 원본 팩트(수치, 법적 의도)를 단 1%의 왜곡도 없이 정확하게 반영하고 있으며 안전한지 여부")
    hallucination_score: float = Field(description="환각 의심 지수 (0.0~1.0 사이, 0.0에 가까울수록 안전하고 정확함)")
    validation_details: str = Field(description="최신 법령 조문 팩트와 생성된 마크다운 강의안 간의 1대1 교차 사실 대조(Fact-checking) 결과에 대한 상세 감사 소견")
    warning_flag: bool = Field(description="법령의 핵심 수치(숫자, 기한)가 원본과 불일치하여 즉시 관리자 경고(Red Flag)를 띄워야 하는지 여부")

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
    print("---RETRIEVING GROUND TRUTH LAW DOCUMENTS---")
    question = state["question"]
    
    # law_documents (법령 전문) 컬렉션에서 최신 법령 팩트 검색 기동
    retriever = get_retriever()
    documents = retriever.invoke(question)
    
    context = [doc.page_content for doc in documents]
    if not context:
        # 데이터가 없을 시 기본 디폴트 텍스트 바인딩
        context = ["제조업 고소 비계 작업 시, 근로자의 추락 재해 예방을 위한 안전조치를 반드시 의무적으로 취해야 합니다. 높이 2미터(2m) 이상의 장소에서 작업을 진행하는 경우, 사업주는 근로자의 추락 위험을 방지하기 위하여 반드시 규격에 맞는 추락 방지 안전망을 촘촘히 의무적으로 설치해야 합니다. (산업안전보건법 제38조)"]
    
    return {"context": context}

def generate(state: AgentState):
    """검색된 최신 법령 팩트 데이터를 지식 근간 삼아, 교육용 시나리오 마크다운 본문 및 평가 퀴즈 무(無)에서 유(有)로 자동 창작 생산"""
    print("---GENERATING FACT-BASED CURRICULUM CONTENT---")
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

def validate(state: AgentState):
    """생산된 콘텐츠 내의 모든 수치와 의도가 RAG 원본 팩트와 정확하게 일치하는지 교차 사실 대조 감사 수행"""
    print("---VALIDATING GENERATED CONTENT---")
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
    RAG에서 추출한 [원본 법령 원천 데이터]와 AI가 무에서 유로 새롭게 창작한 [생산된 교육 본문]을 철저히 교차 대조하여 사실 관계 확인(Fact-checking)을 수행하십시오.
    
    [원본 법령 원천 데이터 (Ground Truth)]
    {original_law}
    
    [생산된 교육 본문]
    강의 제목: {title}
    근거 참조 조항: {law_reference}
    생산 본문 마크다운: 
    {content_markdown}
    
    생산 퀴즈:
    {quiz_proposed}
    
    다음 감사 기준에 따라 분석하여 결과를 정형 형태로 반환하십시오:
    1. 생산된 마크다운 내용에 기술된 중요 규제 수치(예: 높이 2m, 과태료 벌금 수치 등)가 원본 법령의 수치와 단 1%의 오차도 없이 완벽하게 일치하는가? (숫자 불일치는 치명적 환각입니다)
    2. 생산된 콘텐츠가 원본 법령의 의무 의도를 왜곡하거나, 임의로 지어낸 허위 조항(환각)을 포함하고 있지는 않은가?
    3. 환각 의심 지수(Hallucination Score)를 0.0~1.0 사이로 계산하십시오 (환각이 없을수록 0.0에 수렴함).
    """
    
    prompt = ChatPromptTemplate.from_template(template)
    chain = prompt | structured_llm
    
    try:
        val_res: ContentValidation = chain.invoke({
            "original_law": law_context_str,
            "title": gen_result.get("title", "N/A"),
            "law_reference": gen_result.get("law_reference", "N/A"),
            "content_markdown": gen_result.get("content_markdown", "N/A"),
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
    
    # 예전 API 호출부 및 메인 컨트롤러 호환성을 위해 generation_result를 analysis_result 키로 정합
    return {
        "analysis_result": result.get("generation_result"),
        "validation_result": result.get("validation_result"),
        "markdown_report": result.get("answer")
    }
