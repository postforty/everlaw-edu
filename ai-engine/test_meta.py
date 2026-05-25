from app.core.database import engine
from sqlalchemy import text

res = engine.connect().execute(text("""
    SELECT cmetadata->>'law_name', cmetadata->>'article', document
    FROM langchain_pg_embedding 
    WHERE CONCAT(cmetadata->>'law_name', ' ', cmetadata->>'article') = '산업안전보건법 제1조'
""")).fetchall()

for r in res:
    print(r[0], r[1], r[2][:100])
