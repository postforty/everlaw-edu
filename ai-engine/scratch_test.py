import sys
sys.stdout.reconfigure(encoding='utf-8')
from app.core.database import engine
from sqlalchemy import text

with engine.connect() as conn:
    res = conn.execute(text("SELECT cmetadata->>'law_name', cmetadata->>'law_type', cmetadata->>'Header 2', cmetadata->>'article', document FROM langchain_pg_embedding WHERE document LIKE '%별표 9%' OR cmetadata->>'Header 2' LIKE '%별표 9%' LIMIT 5")).fetchall()
    for r in res:
        print(f"Name:{r[0]} Type:{r[1]} Header:{r[2]} Article:{r[3]}")
        print(f"Doc: {r[4][:300]}...")
        print("---")
