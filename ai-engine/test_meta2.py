from app.core.database import engine
from sqlalchemy import text

res = engine.connect().execute(text("""
    SELECT document
    FROM langchain_pg_embedding 
    WHERE CONCAT(cmetadata->>'law_name', ' ', cmetadata->>'article') = '산업안전보건법 제1조'
""")).fetchall()

for i, r in enumerate(res):
    print(f"[{i}]", r[0][:150])
