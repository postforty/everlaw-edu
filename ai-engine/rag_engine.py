import os
from dotenv import load_dotenv
from langchain_ollama import OllamaLLM, OllamaEmbeddings
from langchain_community.vectorstores import PGVector
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough

load_dotenv()

# Configuration
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL")
POSTGRES_URL = os.getenv("POSTGRES_URL")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL")
LLM_MODEL = os.getenv("LLM_MODEL")

# Initialize Ollama
embeddings = OllamaEmbeddings(
    base_url=OLLAMA_BASE_URL,
    model=EMBEDDING_MODEL
)

llm = OllamaLLM(
    base_url=OLLAMA_BASE_URL,
    model=LLM_MODEL
)

# Initialize Vector Store (using pgvector)
CONNECTION_STRING = POSTGRES_URL
COLLECTION_NAME = "law_documents"

def get_vector_store():
    return PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME,
    )

# RAG Chain Setup
template = """개정된 법령 정보를 바탕으로 기존 교육 콘텐츠를 어떻게 수정해야 할지 분석하고, 새로운 강의안(마크다운)과 퀴즈를 생성해줘.

관련 법령 정보:
{context}

사용자 요청:
{question}

분석 결과 및 생성된 콘텐츠:
"""
prompt = ChatPromptTemplate.from_template(template)

def generate_rag_content(question: str):
    vector_store = get_vector_store()
    retriever = vector_store.as_retriever()
    
    chain = (
        {"context": retriever, "question": RunnablePassthrough()}
        | prompt
        | llm
        | StrOutputParser()
    )
    
    return chain.invoke(question)
