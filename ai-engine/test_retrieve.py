import asyncio
from app.services.adaptive_generator import retrieve_law

async def main():
    state = {
        "law_reference": "산업안전보건법 제1조",
        "previous_questions": []
    }
    res = await retrieve_law(state)
    print("Result Context Length:", len(res["context"]))
    print("Context Preview:", res["context"][0][:100])

if __name__ == "__main__":
    asyncio.run(main())
