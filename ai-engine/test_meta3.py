from app.core.database import engine
from sqlalchemy import text

res = engine.connect().execute(text("""
    SELECT document
    FROM langchain_pg_embedding 
    WHERE cmetadata->>'law_name' = '산업안전보건법' AND cmetadata->>'article' = '제1조'
""")).fetchall()

for i, r in enumerate(res):
    print(f"[{i}]", r[0][:100].replace('\n', ' '))
