import sys
import os

# ai-engine 폴더를 python path에 추가
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from sqlalchemy import create_engine, text as sql_text
from app.core.config import CONNECTION_STRING

def clean_database_noise():
    print("🧹 [EverLaw DB Housekeeping] 데이터베이스 정제 파이프라인 기동...")
    try:
        engine = create_engine(CONNECTION_STRING)
        with engine.connect() as conn:
            # 1. 삭제 전, 정제 대상 노이즈 법령 수량 카운트 조회
            count_query = sql_text("""
                SELECT COUNT(*) FROM langchain_pg_embedding
                WHERE collection_id = (SELECT uuid FROM langchain_pg_collection WHERE name = 'law_documents')
                  AND NOT (
                    cmetadata->>'law_name' LIKE '%산업안전보건법%' OR
                    cmetadata->>'law_name' LIKE '%중대재해%' OR
                    cmetadata->>'law_name' LIKE '%근로기준법%'
                  )
            """)
            noise_count = conn.execute(count_query).scalar()
            print(f"🔍 [조회 결과] 도메인 외 노이즈 법령 데이터 개수: {noise_count}개")
            
            if noise_count == 0:
                print("🟢 [완료] 데이터베이스가 이미 100% 무결한 상태입니다. 정제를 생략합니다.")
                return

            # 2. 노이즈 데이터 일괄 DELETE 단행 (하우스키핑)
            delete_query = sql_text("""
                DELETE FROM langchain_pg_embedding
                WHERE collection_id = (SELECT uuid FROM langchain_pg_collection WHERE name = 'law_documents')
                  AND NOT (
                    cmetadata->>'law_name' LIKE '%산업안전보건법%' OR
                    cmetadata->>'law_name' LIKE '%중대재해%' OR
                    cmetadata->>'law_name' LIKE '%근로기준법%'
                  )
            """)
            result = conn.execute(delete_query)
            conn.commit()
            print(f"🧹 [대성공] {noise_count}개의 도메인 외 노이즈 법령 데이터를 pgvector DB에서 완벽하게 소거 완료했습니다!")
            
    except Exception as e:
        print(f"❌ [에러] 데이터베이스 정제 중 실패: {e}")

if __name__ == "__main__":
    clean_database_noise()
