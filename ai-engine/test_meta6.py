import json
from app.core.database import engine
from sqlalchemy import text

res = engine.connect().execute(text("""
    SELECT cmetadata
    FROM langchain_pg_embedding 
    WHERE cmetadata->>'law_name' = '산업안전보건법' AND cmetadata->>'article' = '제1조'
""")).fetchone()

if res:
    cmetadata = res[0] if not isinstance(res[0], str) else json.loads(res[0])
    with open('test_out3.txt', 'w', encoding='utf-8') as f:
        json.dump(cmetadata, f, ensure_ascii=False, indent=2)
