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

def get_retriever():
    vector_store = PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME,
    )
    return vector_store.as_retriever()

# LangGraph State Definition
class AgentState(TypedDict):
    question: str
    context: List[str]
    answer: str

# Nodes
def retrieve(state: AgentState):
    print("---RETRIEVING---")
    question = state["question"]
    retriever = get_retriever()
    documents = retriever.get_relevant_documents(question)
    context = [doc.page_content for doc in documents]
    return {"context": context}

def generate(state: AgentState):
    print("---GENERATING---")
    question = state["question"]
    context = state["context"]
    
    template = """당신은 법률 전문 AI 에이전트입니다. 개정된 법령 정보를 바탕으로 기존 교육 콘텐츠의 수정안을 제시하세요.
    
    관련 법령 정보:
    {context}
    
    사용자 요청:
    {question}
    
    분석 결과 및 생성된 콘텐츠(마크다운 형식):
    """
    prompt = ChatPromptTemplate.from_template(template)
    chain = prompt | llm
    
    response = chain.invoke({"context": "\n".join(context), "question": question})
    return {"answer": response.content}

# Graph Construction
workflow = StateGraph(AgentState)

# Add Nodes
workflow.add_node("retrieve", retrieve)
workflow.add_node("generate", generate)

# Set Entry Point and Edges
workflow.set_entry_point("retrieve")
workflow.add_edge("retrieve", "generate")
workflow.add_edge("generate", END)

# Compile Graph
app = workflow.compile()

def generate_rag_content(question: str):
    # Execute Graph
    inputs = {"question": question}
    result = app.invoke(inputs)
    return result["answer"]
