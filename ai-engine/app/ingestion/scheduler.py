import hashlib
import feedparser
from datetime import datetime
from github import Github, GithubException
from app.core.config import r, MOEL_RSS_URL, GITHUB_REPO, GITHUB_TOKEN
from app.ingestion.parser import extract_added_text_from_patch, extract_fine_grained_law_metadata, split_law_markdown_to_documents
from app.core.database import add_documents_to_vector_store_bulk

class LawScanner:
    def __init__(self):
        self.moel_rss_url = MOEL_RSS_URL
        self.github_repo = GITHUB_REPO
        
        # GITHUB_TOKEN은 수집 빈도가 낮아 불필요하므로 생략 가능하며, 있을 때만 적용하도록 안전하게 처리
        github_token = GITHUB_TOKEN
        if github_token and "your_github_token" not in github_token:
            self.gh = Github(github_token)
        else:
            self.gh = Github()  # 익명(Anonymous) 클라이언트로 초기화

    def scan_moel_rss(self):
        """고용노동부 공지사항 RSS 스캔"""
        print(f"[{datetime.now()}] Scanning MOEL RSS: {self.moel_rss_url}")
        feed = feedparser.parse(self.moel_rss_url)
        new_items = []

        for entry in feed.entries:
            content_id = hashlib.md5(entry.link.encode()).hexdigest()
            # Redis가 사용 가능한 경우 멱등성 캐시 조회
            if r and not r.exists(f"law_scan:rss:{content_id}"):
                item = {
                    "title": entry.title,
                    "link": entry.link,
                    "published": entry.published,
                    "summary": entry.summary,
                    "source": "MOEL"
                }
                new_items.append(item)
                r.setex(f"law_scan:rss:{content_id}", 2592000, "seen")
                print(f"New law found in RSS: {entry.title}")
            elif not r:
                print("⚠️ Redis가 없어 RSS 멱등성 체크를 우회합니다.")
        return new_items

    def scan_national_law_api(self, query="산업안전보건법"):
        """국가법령정보센터 API 스캔 (Skeleton)"""
        print(f"[{datetime.now()}] Scanning National Law API for: {query}")
        return []

    def scan_legalize_kr_github_api(self):
        """GitHub API를 통해 저장소의 최신 변경 사항 감지 및 RAG 벡터 DB 자동 적재 (조 단위 완결성 & 멱등성 보장)"""
        print(f"[{datetime.now()}] Scanning GitHub API: {self.github_repo}")
        try:
            repo = self.gh.get_repo(self.github_repo)
            # 마지막 5개의 커밋 확인
            commits = [c for c in repo.get_commits()[:5]]
            new_changes = []

            for commit in commits:
                content_id = commit.sha
                if r and not r.exists(f"law_scan:gh:{content_id}"):
                    files = []
                    # 변경된 파일별로 패치를 분석하여 실질적 개정 텍스트 추출 및 임베딩 적재
                    for file in commit.files:
                        files.append(file.filename)
                        if file.filename.endswith('.md') and file.patch:
                            # 1. 법령 이름 및 종류 추출
                            law_name = "산업안전보건법"
                            law_type = "법률"
                            
                            if "시행령" in file.filename:
                                law_type = "시행령"
                            elif "시행규칙" in file.filename:
                                law_type = "시행규칙"
                                
                            if "산업안전보건법" not in file.filename:
                                parts = file.filename.split('/')
                                if len(parts) >= 2:
                                    law_name = parts[-2]

                            # 💡 [엄격한 파일 경로 필터링] 오직 산업안전보건법 3대 원본 파일만 RAG 수집 대상으로 허용 (오염률 0% 보장)
                            ALLOWED_PATHS = [
                                "kr/산업안전보건법/법률.md",
                                "kr/산업안전보건법/시행령.md",
                                "kr/산업안전보건법/시행규칙.md"
                            ]
                            if file.filename not in ALLOWED_PATHS:
                                print(f"🟢 [엄격 필터 스킵] 수집 비대상 법령 파일입니다. 적재 생략 (파일명: {file.filename})")
                                continue

                            processed_articles = False
                            try:
                                # 전체 파일을 다운로드하고 공통 파이프라인으로 전체 청킹
                                print(f"📥 [실시간 수집] '{file.filename}' 전문 다운로드 개시...")
                                file_content = repo.get_contents(file.filename, ref=commit.sha).decoded_content.decode('utf-8')
                                
                                docs = split_law_markdown_to_documents(
                                    file_content=file_content,
                                    law_name=law_name,
                                    law_type=law_type,
                                    source=f"GitHub ({self.github_repo})"
                                )
                                
                                # 모든 청크에 실시간 메타데이터 이식
                                for doc in docs:
                                    doc.metadata["sha"] = commit.sha
                                    doc.metadata["commit_sha"] = commit.sha
                                    doc.metadata["commit_message"] = commit.commit.message.split('\n')[0]
                                    doc.metadata["url"] = commit.html_url
                                    doc.metadata["filename"] = file.filename
                                    
                                # 단 1번의 벌크 CDC 및 단일 배치 임베딩 적재 개시!
                                add_documents_to_vector_store_bulk(docs)
                                
                                processed_articles = True
                            except Exception as fe:
                                print(f"⚠️ [경고] 전문 획득 및 청킹 실패 (Fallback 모드로 진입): {fe}")

                            # Fallback: 전문 획득 실패 시 패치 단위 적재
                            if not processed_articles:
                                added_text = extract_added_text_from_patch(file.patch)
                                if added_text:
                                    fallback_metadata = {
                                        "source": f"GitHub ({self.github_repo})",
                                        "sha": commit.sha,
                                        "commit_sha": commit.sha,
                                        "filename": file.filename,
                                        "law_name": law_name,
                                        "law_type": law_type,
                                        "commit_message": commit.commit.message.split('\n')[0],
                                        "url": commit.html_url
                                    }
                                    fine_metadata = extract_fine_grained_law_metadata(added_text, fallback_metadata)
                                    try:
                                        add_document_to_vector_store(added_text, fine_metadata)
                                        print(f"ℹ️ [완료] 패치 단위 폴백 업서트 처리 완료: {law_name}")
                                    except Exception as ve:
                                        print(f"[{datetime.now()}] Failed to load to vector DB: {ve}")



                    change_item = {
                        "title": commit.commit.message.split('\n')[0],
                        "sha": commit.sha,
                        "url": commit.html_url,
                        "files": files,
                        "source": f"GitHub ({self.github_repo})"
                    }
                    new_changes.append(change_item)
                    r.setex(f"law_scan:gh:{content_id}", 2592000, "seen")
                    print(f"New GitHub commit found & processed: {change_item['title']}")
                elif not r:
                    print("⚠️ Redis가 없어 GitHub 멱등성 체크를 우회합니다.")
            return new_changes
        except GithubException as ge:
            status_code = getattr(ge, 'status', 'N/A')
            error_message = getattr(ge, 'data', {}).get('message', str(ge))
            print(f"⚠️ [GitHub API 에러 발생] Status Code: {status_code} | Message: {error_message}")
            if status_code == 403 and "rate limit" in error_message.lower():
                print("🔴 [안내] GitHub API 호출 속도 제한(Rate Limit)에 도달했습니다. GITHUB_TOKEN을 설정하여 주입하거나 1시간 후 재시도하십시오.")
            return []
        except Exception as e:
            print(f"Error scanning GitHub API: {e}")
            return []

    def run_all_scanners(self):
        """전체 스캐너 실행 및 결과 통합"""
        results = []
        results.extend(self.scan_moel_rss())
        results.extend(self.scan_national_law_api())
        results.extend(self.scan_legalize_kr_github_api())
        return results
