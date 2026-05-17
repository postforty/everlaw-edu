import json
import hashlib
from typing import List
from sqlalchemy import create_engine, text as sql_text
from langchain_community.vectorstores import PGVector
from langchain_core.documents import Document
from app.core.config import embeddings, CONNECTION_STRING, COLLECTION_NAME, COLLECTION_NAME_CURRICULUM

def get_retriever():
    """최신 법령 전문(Ground Truth) 저장 테이블에서 검색을 수행하는 리트리버 획득"""
    vector_store = PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME,
    )
    return vector_store.as_retriever()

def get_curriculum_retriever():
    """생산된 교육 커리큘럼 테이블에서 검색을 수행하는 리트리버 획득"""
    vector_store = PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME_CURRICULUM,
    )
    return vector_store.as_retriever()

def add_document_to_vector_store(text: str, metadata: dict):
    """추출된 개정 법령 텍스트를 pgvector에 임베딩 및 적재 (신선도 유지를 위한 SQL-level Upsert 지원)"""
    print("---ADDING DOCUMENT TO VECTOR STORE (REFRACTORED)---")
    vector_store = PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME,
    )
    
    import hashlib
    current_hash = hashlib.sha256(text.encode('utf-8')).hexdigest()
    metadata["chunk_hash"] = current_hash
    
    doc = Document(page_content=text, metadata=metadata)
    
    # law_name과 article(조)을 조합한 고유 비즈니스 키를 생성하여, 커밋이 변경되더라도 동일한 '조'는 항상 물리적으로 삭제 후 인서트되도록 보장
    law_name = metadata.get("law_name")
    article = metadata.get("article")
    
    if law_name and article:
        custom_id = f"law_{law_name}_{article}"
    else:
        law_key = metadata.get("law_id") or metadata.get("commit_sha")
        custom_id = f"law_{law_key}" if law_key else None
    
    if custom_id:
        # [해시 CDC 비교] 기존 레코드가 이미 존재하고 본문 해시가 같으면 완벽한 무변경이므로 프로세스 스킵
        try:
            engine = create_engine(CONNECTION_STRING)
            with engine.connect() as conn:
                result = conn.execute(
                    sql_text("SELECT cmetadata FROM langchain_pg_embedding WHERE custom_id = :custom_id"),
                    {"custom_id": custom_id}
                ).fetchone()
                
                if result and result[0]:
                    cmetadict = result[0]
                    if isinstance(cmetadict, str):
                        try:
                            cmetadict = json.loads(cmetadict)
                        except:
                            cmetadict = {}
                    
                    old_hash = cmetadict.get("chunk_hash")
                    if old_hash == current_hash:
                        print(f"🟢 [SKIP] 동일한 청크 해시 감지 (Key: {custom_id}, Hash: {current_hash[:8]}). 업데이트를 생략합니다.")
                        return
        except Exception as he:
            print(f"⚠️ [경고] 기존 해시 대조 에러 (업데이트 강제 기동): {he}")

        # [물리적 중복 제거] LangChain PK 제약조건 한계를 무력화하기 위해 적재 전 기존 custom_id를 완전히 DELETE
        try:
            engine = create_engine(
                CONNECTION_STRING,
                json_serializer=lambda obj: json.dumps(obj, ensure_ascii=False)
            )
            with engine.connect() as conn:
                conn.execute(
                    sql_text("DELETE FROM langchain_pg_embedding WHERE custom_id = :custom_id"),
                    {"custom_id": custom_id}
                )
                conn.commit()
            print(f"🧹 [성공] 기존 동일 법령(Key: {custom_id}) 물리적 청소 완료")
        except Exception as e:
            print(f"⚠️ [경고] 적재 전 청소 에러 (무시하고 적재 진행): {e}")

        vector_store.add_documents([doc], ids=[custom_id])
    else:
        vector_store.add_documents([doc])
    print(f"Document successfully added/updated with key: {custom_id or 'Auto-UUID'}")

def add_curriculum_to_vector_store(text: str, metadata: dict):
    """기존 교육 커리큘럼의 개별 강의안(Markdown)을 pgvector에 적재 (최신성/신선도 유지를 위한 SQL-level Upsert 지원)"""
    print("---ADDING CURRICULUM TO VECTOR STORE (REFRACTORED)---")
    vector_store = PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME_CURRICULUM,
    )
    
    import hashlib
    current_hash = hashlib.sha256(text.encode('utf-8')).hexdigest()
    metadata["chunk_hash"] = current_hash
    
    doc = Document(page_content=text, metadata=metadata)
    
    # lesson_id를 고유 식별자 키로 삼아 항상 최신 버전의 강의안만 유지
    lesson_id = metadata.get("lesson_id")
    custom_id = f"lesson_{lesson_id}" if lesson_id else None
    
    if custom_id:
        # [해시 CDC 비교] 기존 레코드가 이미 존재하고 본문 해시가 같으면 완벽한 무변경이므로 프로세스 스킵
        try:
            engine = create_engine(CONNECTION_STRING)
            with engine.connect() as conn:
                result = conn.execute(
                    sql_text("SELECT cmetadata FROM langchain_pg_embedding WHERE custom_id = :custom_id"),
                    {"custom_id": custom_id}
                ).fetchone()
                
                if result and result[0]:
                    cmetadict = result[0]
                    if isinstance(cmetadict, str):
                        try:
                            cmetadict = json.loads(cmetadict)
                        except:
                            cmetadict = {}
                    
                    old_hash = cmetadict.get("chunk_hash")
                    if old_hash == current_hash:
                        print(f"🟢 [SKIP] 동일한 강의안 해시 감지 (Key: {custom_id}, Hash: {current_hash[:8]}). 업데이트를 생략합니다.")
                        return
        except Exception as he:
            print(f"⚠️ [경고] 기존 해시 대조 에러 (업데이트 강제 기동): {he}")

        # [물리적 중복 제거] LangChain PK 제약조건 한계를 무력화하기 위해 적재 전 기존 custom_id를 완전히 DELETE
        try:
            engine = create_engine(CONNECTION_STRING)
            with engine.connect() as conn:
                conn.execute(
                    sql_text("DELETE FROM langchain_pg_embedding WHERE custom_id = :custom_id"),
                    {"custom_id": custom_id}
                )
                conn.commit()
            print(f"🧹 [성공] 기존 동일 강의안(Key: {custom_id}) 물리적 청소 완료")
        except Exception as e:
            print(f"⚠️ [경고] 적재 전 청소 에러 (무시하고 적재 진행): {e}")

        vector_store.add_documents([doc], ids=[custom_id])
    else:
        vector_store.add_documents([doc])
    print(f"Curriculum document successfully added/updated with key: {custom_id or 'Auto-UUID'} ({metadata.get('title', 'Untitled')})")

def retrieve_affected_curriculum(law_content: str) -> List[dict]:
    """개정 법령 텍스트를 기준으로 가장 유사도 높은(영향을 받을 가능성이 큰) 기존 커리큘럼 강의안들을 검색"""
    print("---RETRIEVING AFFECTED CURRICULUM (REFRACTORED)---")
    retriever = get_curriculum_retriever()
    documents = retriever.invoke(law_content)
    
    affected_lessons = []
    for doc in documents:
        affected_lessons.append({
            "lesson_id": doc.metadata.get("lesson_id"),
            "curriculum_id": doc.metadata.get("curriculum_id"),
            "title": doc.metadata.get("title", "Unknown Lesson"),
            "content": doc.page_content
        })
    return affected_lessons
