from app.core.database import engine
from sqlalchemy import text

res = engine.connect().execute(text("""
    SELECT cmetadata->>'law_name', cmetadata->>'article' 
    FROM langchain_pg_embedding 
    WHERE cmetadata->>'law_name' = '산업안전보건법' 
    LIMIT 5
""")).fetchall()

print("With article:", res)

res2 = engine.connect().execute(text("""
    SELECT cmetadata->>'law_name', cmetadata->>'article' 
    FROM langchain_pg_embedding 
    WHERE cmetadata->>'law_name' = '산업안전보건법' 
    AND cmetadata->>'article' = '제1조'
""")).fetchall()

print("Exact 제1조:", res2)
