import asyncio
from app.core.database import get_retriever

async def test_retrieval():
    retriever = get_retriever()
    docs = await retriever.ainvoke("산업안전보건법 시행령 별표 9")
    for i, doc in enumerate(docs[:3]):
        print(f"--- DOC {i} ---")
        print(doc.page_content[:300])

if __name__ == "__main__":
    asyncio.run(test_retrieval())
