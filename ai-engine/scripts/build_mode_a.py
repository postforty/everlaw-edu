import sys
import os
import requests
import json
from sqlalchemy import text as sql_text

# Add ai-engine to PYTHONPATH
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import engine

SPRING_BOOT_URL = "http://localhost:8080"
TARGET_LAW_NAME = "산업안전보건법"
TARGET_ARTICLE = "제1조"

def get_existing_curriculums():
    """Fetch existing approval requests to check idempotency."""
    try:
        response = requests.get(f"{SPRING_BOOT_URL}/api/v1/approvals")
        if response.status_code == 200:
            data = response.json()
            return [req.get("lawReference") for req in data if req.get("lawReference")]
        else:
            print(f"Failed to fetch approvals: HTTP {response.status_code}")
            return []
    except Exception as e:
        print(f"Error fetching existing approvals: {e}")
        # Spring Boot 서버가 아직 실행 중이 아니거나 통신 에러가 발생한 경우
        return []

def trigger_generation(law_id, law_content):
    """Trigger generation via Spring Boot."""
    url = f"{SPRING_BOOT_URL}/api/v1/approvals/generate"
    payload = {
        "curriculumId": 1,  # Fallback for old backend
        "lawId": law_id,
        "lawContent": law_content
    }
    try:
        response = requests.post(url, json=payload)
        response.raise_for_status()
        print(f"✅ Successfully triggered generation for {law_id}")
    except Exception as e:
        print(f"❌ Failed to trigger generation for {law_id}: {e}")
        if hasattr(e, 'response') and e.response:
            print(f"Response: {e.response.text}")

def main():
    print(f"🚀 Starting Mode A Bulk Generation (MVP: {TARGET_LAW_NAME} {TARGET_ARTICLE})")
    
    existing_laws = get_existing_curriculums()
    print(f"📋 Found {len(existing_laws)} existing approval requests.")

    try:
        with engine.connect() as conn:
            query = sql_text("""
                SELECT document, cmetadata 
                FROM langchain_pg_embedding 
                WHERE cmetadata->>'law_name' = :law_name 
                  AND cmetadata->>'article' = :article
            """)
            result = conn.execute(query, {"law_name": TARGET_LAW_NAME, "article": TARGET_ARTICLE}).fetchall()
            
            if not result:
                print(f"⚠️ No data found in pgvector for {TARGET_LAW_NAME} {TARGET_ARTICLE}")
                return

            for row in result:
                content = row[0]
                metadata = row[1]
                
                if isinstance(metadata, str):
                    metadata = json.loads(metadata)
                
                law_id = f"{TARGET_LAW_NAME} {TARGET_ARTICLE}"
                
                if law_id in existing_laws:
                    print(f"⏭️ Skipping {law_id} - already exists in approval queue.")
                else:
                    print(f"▶️ Processing {law_id}...")
                    trigger_generation(law_id, content)

    except Exception as e:
        print(f"❌ Database error: {e}")

if __name__ == "__main__":
    main()
