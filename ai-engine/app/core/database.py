import json
import hashlib
from typing import List
from sqlalchemy import create_engine, text as sql_text
from langchain_community.vectorstores import PGVector
from langchain_core.documents import Document
from app.core.config import embeddings, CONNECTION_STRING, COLLECTION_NAME, COLLECTION_NAME_CURRICULUM, EMBEDDING_BATCH_SIZE

# database.py의 모듈 수준 싱글톤 데이터베이스 엔진 생성
# pool_size, max_overflow, pool_recycle 등 프로덕션 커넥션 풀 성능 튜닝 매개변수 적용
engine = create_engine(
    CONNECTION_STRING,
    pool_size=20,
    max_overflow=10,
    pool_recycle=3600,
    json_serializer=lambda obj: json.dumps(obj, ensure_ascii=False)
)

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

async def retrieve_affected_curriculum_async(law_content: str) -> List[dict]:
    """개정 법령 텍스트를 기준으로 가장 유사도 높은(영향을 받을 가능성이 큰) 기존 커리큘럼 강의안들을 비동기 검색"""
    print("---RETRIEVING AFFECTED CURRICULUM ASYNC---")
    retriever = get_curriculum_retriever()
    documents = await retriever.ainvoke(law_content)
    
    affected_lessons = []
    for doc in documents:
        affected_lessons.append({
            "lesson_id": doc.metadata.get("lesson_id"),
            "curriculum_id": doc.metadata.get("curriculum_id"),
            "title": doc.metadata.get("title", "Unknown Lesson"),
            "content": doc.page_content
        })
    return affected_lessons

def add_documents_to_vector_store_bulk(documents: List[Document]):
    """다수의 법령 청크를 배치 단위로 고속 임베딩 및 물리적 적재 (소켓 고갈 및 Ollama 데드락 방지, 벌크 CDC 및 멱등성 보장)"""
    if not documents:
        print("🟢 적재할 문서가 존재하지 않습니다.")
        return
        
    print(f"\n⚡ [벌크 적재 개시] 총 {len(documents)}개 청크의 대용량 RAG 적재 파이프라인 기동...")
    vector_store = PGVector(
        connection_string=CONNECTION_STRING,
        embedding_function=embeddings,
        collection_name=COLLECTION_NAME,
    )
    
    # 1. 문서별 고유 비즈니스 키(custom_id) 및 해시 생성
    doc_map = {}  # custom_id -> (Document, current_hash)
    for doc in documents:
        # 본문 해시 생성 및 메타데이터 주입
        current_hash = hashlib.sha256(doc.page_content.encode('utf-8')).hexdigest()
        doc.metadata["chunk_hash"] = current_hash
        
        law_name = doc.metadata.get("law_name")
        article = doc.metadata.get("article")
        
        if law_name and article:
            custom_id = f"law_{law_name}_{article}"
        else:
            law_key = doc.metadata.get("law_id") or doc.metadata.get("commit_sha")
            custom_id = f"law_{law_key}" if law_key else None
            
        if not custom_id:
            # Fallback UUID
            import uuid
            custom_id = f"law_auto_{uuid.uuid4().hex}"
            
        doc_map[custom_id] = (doc, current_hash)
        
    custom_ids = list(doc_map.keys())
    
    # 2. [벌크 CDC 해시 대조] 단 1번의 SELECT 쿼리로 이미 존재하는 청크들의 기존 해시 조회
    existing_hashes = {}
    try:
        with engine.connect() as conn:
            # 안전하게 파라미터화된 바인딩 사용
            # SQLAlchemy IN 조건 처리
            query = sql_text("SELECT custom_id, cmetadata FROM langchain_pg_embedding WHERE custom_id IN (SELECT unnest(:ids))")
            result = conn.execute(query, {"ids": custom_ids}).fetchall()
            for row in result:
                cid, cmetadata = row[0], row[1]
                if cmetadata:
                    if isinstance(cmetadata, str):
                        try:
                            cmetadata = json.loads(cmetadata)
                        except:
                            cmetadata = {}
                    existing_hashes[cid] = cmetadata.get("chunk_hash")
    except Exception as he:
        print(f"⚠️ [경고] 벌크 해시 CDC 조회 에러 (전체 강제 적재 진행): {he}")

    # 3. 해시가 동일한 무변경 청크 필터링 (Bulk Skip)
    final_docs = []
    final_ids = []
    skip_count = 0
    
    for cid, (doc, curr_hash) in doc_map.items():
        old_hash = existing_hashes.get(cid)
        if old_hash and old_hash == curr_hash:
            skip_count += 1
        else:
            final_docs.append(doc)
            final_ids.append(cid)
            
    print(f"🟢 [벌크 CDC] 전체 {len(documents)}개 중 무변경 스킵: {skip_count}개 | 신규/개정 적재 대상: {len(final_docs)}개")
    
    if not final_docs:
        print("🟢 [완료] 적재할 변경 대상이 전혀 존재하지 않아 파이프라인을 종료합니다.")
        return
        
    # 4. [벌크 멱등성 클렌징] 신규 적재 대상 청크들에 대해 단 1번의 벌크 DELETE 단행
    try:
        with engine.connect() as conn:
            delete_query = sql_text("DELETE FROM langchain_pg_embedding WHERE custom_id IN (SELECT unnest(:ids))")
            conn.execute(delete_query, {"ids": final_ids})
            conn.commit()
        print(f"🧹 [성공] 기존 낡은 멱등성 청크 {len(final_ids)}개 벌크 SQL DELETE 소거 완료")
    except Exception as de:
        print(f"⚠️ [경고] 벌크 적재 전 클렌징 에러 (무시하고 적재 강행): {de}")
        
    # 5. [Ollama 최적화 슬라이싱 배치 적재] - 단일 배치 한계 및 메모리 과부하 예방
    batch_size = EMBEDDING_BATCH_SIZE
    try:
        print(f"🚀 [Ollama & DB] 총 {len(final_docs)}개 청크를 {batch_size}개씩 쪼개어 슬라이싱 배치 임베딩 및 DB 적재 단행...")
        for idx in range(0, len(final_docs), batch_size):
            batch_docs = final_docs[idx:idx + batch_size]
            batch_ids = final_ids[idx:idx + batch_size]
            print(f"   ├ ⚡ [배치 적재 진행] {idx + len(batch_docs)}/{len(final_docs)}개 청크 임베딩 전송 중...")
            vector_store.add_documents(batch_docs, ids=batch_ids)
            
        print(f"🎉 [대성공] {len(final_ids)}개 청크 벌크 적재 및 멱등 Upsert 완전 처리 완료!")
    except Exception as db_err:
        print(f"❌ [치명적 벌크 적재 실패]: {db_err}")
        raise db_err
