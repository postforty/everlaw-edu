import json
from app.core.database import engine
from sqlalchemy import text

res = engine.connect().execute(text("""
    SELECT cmetadata, document
    FROM langchain_pg_embedding 
    WHERE cmetadata->>'law_name' LIKE '산업안전보건법%' AND cmetadata->>'article' = '제1조'
""")).fetchall()

with open('test_out.txt', 'w', encoding='utf-8') as f:
    for i, r in enumerate(res):
        cmetadata = r[0] if not isinstance(r[0], str) else json.loads(r[0])
        law_name = cmetadata.get('law_name')
        f.write(f"[{i}] {law_name} {r[1][:100].replace(chr(10), ' ')}\n")
