import json
from app.core.database import engine
from sqlalchemy import text

res = engine.connect().execute(text("""
    SELECT DISTINCT cmetadata->>'article'
    FROM langchain_pg_embedding 
    WHERE cmetadata->>'law_name' = '산업안전보건법' 
      AND cmetadata->>'article' LIKE '%1%'
""")).fetchall()

with open('test_out2.txt', 'w', encoding='utf-8') as f:
    for i, r in enumerate(res):
        f.write(f"[{i}] {r[0]}\n")
