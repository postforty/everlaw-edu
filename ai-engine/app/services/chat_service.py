import logging
from typing import List, Dict, Any
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from app.core.config import llm

logger = logging.getLogger(__name__)

async def generate_chat_response_async(message: str, context: str, history: List[Dict[str, Any]] = None) -> str:
    """
    RAG 기반 실시간 자문 비서 응답 생성
    :param message: 사용자의 질문 내용
    :param context: 기준이 되는 법령 조항 및 관련 문맥 (예: "산업안전보건법 제1조")
    :param history: [{"role": "user"|"ai", "content": "text"}] 형태의 단기 메모리용 대화 이력
    :return: AI 비서의 답변 텍스트
    """
    try:
        if history is None:
            history = []

        # LangChain Message 객체로 변환
        chat_history = []
        for msg in history:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            if role == "ai":
                chat_history.append(AIMessage(content=content))
            else:
                chat_history.append(HumanMessage(content=content))

        # 시스템 프롬프트 구성 (페르소나 및 기준 법령 주입)
        system_prompt = f"""당신은 EverLaw Edu의 '준법 실시간 자문 비서'입니다.
사용자는 현재 법정 의무 교육을 수강 중이며, 법령의 실무 적용이나 위반 사례 등에 대해 질문하고 있습니다.
답변 시 다음 지침을 엄격히 준수하세요:
1. 주어진 법령 컨텍스트에 기반하여 답변할 것 (임의의 추측 자제).
2. 법률 비전문가도 이해하기 쉽도록 명확하고 친절한 어투 사용.
3. 근거 조항을 명시하고, 필요 시 실무 위반 예방 사례를 덧붙여 설명할 것.
4. 마크다운 형식을 사용하여 가독성 있게 작성할 것.

[현재 기준 법령 컨텍스트]
{context}
"""

        # 프롬프트 템플릿 생성 (Chat History 포함)
        prompt = ChatPromptTemplate.from_messages([
            ("system", system_prompt),
            MessagesPlaceholder(variable_name="history"),
            ("human", "{question}")
        ])

        # 체인 생성 및 실행
        chain = prompt | llm
        
        response = await chain.ainvoke({
            "history": chat_history,
            "question": message
        })

        content = response.content
        if isinstance(content, list):
            # Extract text from list of blocks (LangChain Google GenAI format)
            text_parts = []
            for part in content:
                if isinstance(part, dict) and "text" in part:
                    text_parts.append(part["text"])
                elif isinstance(part, str):
                    text_parts.append(part)
            return "".join(text_parts)
        return str(content)

    except Exception as e:
        logger.error(f"Error in generate_chat_response_async: {e}")
        raise e
