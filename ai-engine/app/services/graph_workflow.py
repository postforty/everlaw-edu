from langgraph.graph import StateGraph, END
from app.services.generator import AgentState, retrieve, generate
from app.services.validator import validate

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
graph_app = workflow.compile()

def generate_rag_content(question: str) -> dict:
    """FastAPI 및 비동기 파이프라인에서 호출할 RAG 콘텐츠 자동 생성 및 검증 워크플로우 진입점 (동기 버전)"""
    inputs = {"question": question}
    result = graph_app.invoke(inputs)
    
    return {
        "analysis_result": result.get("generation_result"),
        "validation_result": result.get("validation_result"),
        "markdown_report": result.get("answer")
    }

async def generate_rag_content_async(question: str) -> dict:
    """FastAPI 및 비동기 파이프라인에서 호출할 RAG 콘텐츠 자동 생성 및 검증 워크플로우 진입점 (비동기 버전)"""
    inputs = {"question": question}
    result = await graph_app.ainvoke(inputs)
    
    return {
        "analysis_result": result.get("generation_result"),
        "validation_result": result.get("validation_result"),
        "markdown_report": result.get("answer")
    }
