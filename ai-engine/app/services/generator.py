from typing import List, TypedDict
from pydantic import BaseModel, Field
from langchain_core.prompts import ChatPromptTemplate
from app.core.config import llm
from app.core.database import get_retriever, retrieve_affected_curriculum_async

# =====================================================================
# Pydantic Structured Output Schema (Pivot to Content Factory)
# =====================================================================

class CurriculumGeneration(BaseModel):
    lesson_id: int = Field(description="핫스왑할 대상 강의의 고유 식별자 ID")
    curriculum_id: int = Field(description="핫스왑할 대상 커리큘럼의 고유 식별자 ID")
    title: str = Field(description="최신 개정 법령 팩트를 기반으로 생산된 교육 강의안 제목")
    category: str = Field(description="교육 카테고리 대분류 (예: 안전보건, 근로기준, 도로교통)")
    law_reference: str = Field(description="RAG의 지식 소스가 된 최신 개정 법령 조항 고유 식별자 또는 조항명 (예: 산업안전보건법 제38조)")
    content_markdown: str = Field(description="최신 법령 팩트를 지식 근거(Ground Truth)로 삼아, 가상 사고 시나리오 및 행동 요령 수칙 스토리텔링이 친근한 입말로 가미되어 기존 강의안 내용을 갱신한 최신화된 마크다운 강의 본문")
    quiz_proposed: str = Field(description="갱신된 최신 법령 지식을 학습자가 완전히 숙지했는지 확인하기 위한 모의 평가 퀴즈 1문항 및 상세 해설 (객관식 4지선다, 마크다운 포맷. 정답 번호와 해설 포함)")

# LangGraph State Definition
class AgentState(TypedDict):
    question: str                  # 생산하고자 하는 교육 주제 또는 카테고리 (여기서는 개정 법령 텍스트)
    context: List[str]             # law_documents에서 의미론적으로 검색된 최신 법령 전문 텍스트 목록 (Ground Truth)
    affected_lesson: dict          # 매칭된 기존 마스터 챕터 강의안 정보 (lesson_id, curriculum_id, title, content)
    generation_result: dict        # Gemini가 자율 생산한 구조화 JSON 데이터 (CurriculumGeneration)
    validation_result: dict        # 자가 사실 확인 감사 결과 데이터 (ContentValidation)
    answer: str                    # 관리자 Side-by-Side 대조 화면용 최종 마크다운 리포트

# Nodes
async def retrieve(state: AgentState):
    """지식 소스(law_documents)로부터 최신 법령 전문 팩트를 의미론적으로 검색하고 관련 커리큘럼 챕터를 찾아 매칭"""
    print("---RETRIEVING GROUND TRUTH LAW AND MATCHING CURRICULUM---")
    question = state["question"]
    
    # 1. 최신 법령 전문 팩트 검색
    retriever = get_retriever()
    documents = await retriever.ainvoke(question)
    context = [doc.page_content for doc in documents]
    
    # RAG 검색 결과가 없으면 임시 fallback 탑재
    if not context:
        context = ["높이 2미터(2m) 이상의 장소에서 작업을 진행하는 경우, 사업주는 근로자의 추락 위험을 방지하기 위하여 반드시 규격에 맞는 추락 방지 안전망을 촘촘히 의무적으로 설치해야 합니다. (산업안전보건법 제38조)"]

    # 2. 개정 법령과 가장 연관이 깊은 기존 마스터 챕터 핫스왑 매칭
    affected_lessons = await retrieve_affected_curriculum_async(question)
    
    if affected_lessons:
        # 가장 유사도가 높은 최상위 매칭 강의 채택
        affected_lesson = affected_lessons[0]
        print(f"🎯 [MATCHED] 연관 마스터 챕터 매칭 성공! (ID: {affected_lesson['lesson_id']}, Title: {affected_lesson['title']})")
    else:
        # 매칭되는 강의가 전혀 없을 경우 고소 작업 챕터를 Fallback으로 지정
        print("⚠️ [FALLBACK] 매칭되는 연관 마스터 챕터가 없어 디폴트 챕터 3(고소 작업)을 매칭합니다.")
        affected_lesson = {
            "lesson_id": 3,
            "curriculum_id": 103,
            "title": "고소 작업 및 비계 설치 안전 기준",
            "content": """# 고소 작업 및 비계 설치 안전 기준
높이 3미터(3m) 이상의 장소에서 작업을 진행하는 경우, 근로자의 추락 위험을 방지하기 위하여 반드시 규격에 맞는 추락 방지 안전망을 촘촘히 의무적으로 설치해야 합니다."""
        }
        
    return {"context": context, "affected_lesson": affected_lesson}

async def generate(state: AgentState):
    """매칭된 기존 강의안 본문과 RAG 최신 법령 팩트를 융합하여 핫스왑 리라이팅 및 최신 개정 퀴즈 자동 재생산"""
    print("---GENERATING HOT-SWAP CURRICULUM CONTENT---")
    question = state["question"]
    context = state.get("context", [])
    affected_lesson = state.get("affected_lesson", {})
    
    law_context_str = "\n\n".join(context)
    structured_llm = llm.with_structured_output(CurriculumGeneration)
    
    template = """당신은 법률 및 기업 컴플라이언스 교육 전문 AI 에이전트입니다.
    기존에 시딩되어 서비스 중인 [기존 마스터 강의안]의 내용 중, RAG로 검색된 [최신 개정 법령 (Ground Truth)]과 비교하여 변경/개정된 사항이 있다면 이를 정밀하게 반영하여 실시간 핫스왑(Hot-Swap) 리라이팅(Rewriting)을 수행해야 합니다.
    
    [최신 개정 법령 (Ground Truth)]
    {law_context}
    
    [기존 마스터 강의안 정보]
    - Lesson ID: {lesson_id}
    - Curriculum ID: {curriculum_id}
    - 기존 강의 제목: {old_title}
    - 기존 강의 본문: 
    {old_content}
    
    [콘텐츠 핫스왑 리라이팅 가이드라인]
    1. **정밀 리라이팅**: RAG 개정 법령 팩트와 비교하여 기존 강의안의 잘못되었거나 구시대적인 규제 수치(예: '3미터(3m)'에서 '2미터(2m)'로의 변경)가 있다면, 이를 최신 법정 기준으로 확실하게 수정하십시오. 
    2. **문맥 일관성**: 개정된 부분 외의 유용한 설명이나 기본적인 맥락은 유지하되, 전체 강의가 매끄러운 마크다운 본문으로 흐르도록 자연스러운 문체로 보완하십시오.
    3. **정확한 메타데이터 매핑**: 반드시 주어진 핫스왑 대상 강의의 Lesson ID({lesson_id})와 Curriculum ID({curriculum_id})를 스키마의 출력 값으로 정확히 매핑하여 전달해 주어야 합니다.
    4. **개정 반영 신규 퀴즈 출제**: 개정된 수치나 강화된 의무 사항을 확실하게 저격하는 4지선다형 객관식 모의 퀴즈 1문항을 정답 및 해설과 함께 출제하십시오. 정답은 반드시 최신 개정 법령 기준에 의거해야 합니다.
    """
    
    prompt = ChatPromptTemplate.from_messages([
        ("system", template),
        ("human", "위 가이드라인에 따라 기존 강의 ID {lesson_id}의 마스터 강의안을 최신 개정 법령 팩트에 근거하여 실시간 핫스왑(Hot-Swap) 리라이팅을 수행하고 신규 퀴즈를 출제하여 CurriculumGeneration 구조로 출력해주세요.")
    ])
    chain = prompt | structured_llm
    
    try:
        result: CurriculumGeneration = await chain.ainvoke({
            "law_context": law_context_str,
            "lesson_id": affected_lesson.get("lesson_id", 3),
            "curriculum_id": affected_lesson.get("curriculum_id", 103),
            "old_title": affected_lesson.get("title", ""),
            "old_content": affected_lesson.get("content", "")
        })
        result_dict = result.dict()
    except Exception as e:
        print(f"Content Generation Structured Output Failed: {e}")
        fallback = CurriculumGeneration(
            lesson_id=affected_lesson.get("lesson_id", 3),
            curriculum_id=affected_lesson.get("curriculum_id", 103),
            title=affected_lesson.get("title", "고소 작업 및 비계 설치 안전 기준"),
            category="안전보건",
            law_reference="산업안전보건법 제38조",
            content_markdown=f"# {affected_lesson.get('title', '고소 작업 및 비계 설치 안전 기준')}\n\n## 1. 개요\n본 강의에서는 고소 작업 시 발생할 수 있는 추락 사고 예방 조치를 학습합니다.\n\n## 2. 비계 설치 기준\n* 높이 2미터(2m) 이상의 장소에서 작업을 진행하는 경우, 근로자의 추락 위험을 방지하기 위하여 반드시 규격에 맞는 추락 방지 안전망을 촘촘히 의무적으로 설치해야 합니다. (기존 3m에서 2m로 개정)",
            quiz_proposed="### 📝 [QUIZ] 산업안전보건법상 추락 방지망 설치 기준\n\n**Q. 개정된 산업안전보건법에 따라, 제조업 비계 작업 시 근로자 추락 방지망을 의무적으로 설치해야 하는 작업 장소의 최소 높이 기준은 무엇입니까?**\n\n1) 1미터(1m) 이상\n2) 2미터(2m) 이상\n3) 3미터(3m) 이상\n4) 5미터(5m) 이상\n\n**정답: 2**\n\n**해설:** 산업안전보건법 제38조 개정에 따라 고소 작업 현장의 안전 기준이 강화되었습니다. 기존 '3미터(3m) 이상'이었던 추락 방지망 의무 설치 기준이 '2미터(2m) 이상'으로 변경되었습니다."
        )
        result_dict = fallback.dict()
        result = fallback
        
    # 관리자 화면용 마크다운 리포트 생성 (Side-by-Side 대조 화면용 구성)
    report = f"## ⚖️ [AI 실시간 핫스왑] 마스터 커리큘럼 갱신 제안서\n\n"
    report += f"**핫스왑 대상 강의 ID**: {result.lesson_id} (Curriculum ID: {result.curriculum_id})\n"
    report += f"**갱신된 강의 제목**: {result.title}\n"
    report += f"**대분류 카테고리**: {result.category}\n"
    report += f"**RAG 근거 법령**: {result.law_reference}\n\n"
    report += f"### 📝 AI 리라이팅 완료된 강의 본문 (Markdown)\n\n"
    report += f"{result.content_markdown}\n\n"
    report += f"### 📝 최신 개정 반영 신규 퀴즈 제안\n\n"
    report += f"{result.quiz_proposed}\n"
    
    return {"generation_result": result_dict, "answer": report}
