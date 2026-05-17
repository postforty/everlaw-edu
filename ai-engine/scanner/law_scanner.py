import os
import hashlib
import feedparser
import redis
from datetime import datetime
from dotenv import load_dotenv
from github import Github

load_dotenv()

# Redis Setup
REDIS_URL = os.getenv("REDIS_URL")
r = redis.from_url(REDIS_URL)

class LawScanner:
    def __init__(self):
        self.moel_rss_url = os.getenv("MOEL_RSS_URL")
        self.law_api_endpoint = os.getenv("LAW_API_ENDPOINT")
        # 기본값으로 'legalize-kr/legalize-kr'을 지정하여 환경변수가 없어도 작동하도록 함
        self.github_repo = os.getenv("GITHUB_REPO", "legalize-kr/legalize-kr")
        
        # GITHUB_TOKEN은 수집 빈도가 낮아 불필요하므로 생략 가능하며, 있을 때만 적용하도록 안전하게 처리
        github_token = os.getenv("GITHUB_TOKEN")
        if github_token and "your_github_token" not in github_token:
            self.gh = Github(github_token)
        else:
            self.gh = Github() # 익명(Anonymous) 클라이언트로 초기화

    def scan_moel_rss(self):
        """고용노동부 공지사항 RSS 스캔"""
        print(f"[{datetime.now()}] Scanning MOEL RSS: {self.moel_rss_url}")
        feed = feedparser.parse(self.moel_rss_url)
        new_items = []

        for entry in feed.entries:
            content_id = hashlib.md5(entry.link.encode()).hexdigest()
            if not r.exists(f"law_scan:rss:{content_id}"):
                item = {
                    "title": entry.title,
                    "link": entry.link,
                    "published": entry.published,
                    "summary": entry.summary,
                    "source": "MOEL"
                }
                new_items.append(item)
                r.setex(f"law_scan:rss:{content_id}", 2592000, "seen")
                print(f"New law found: {entry.title}")
        return new_items

    def scan_national_law_api(self, query="산업안전보건법"):
        """국가법령정보센터 API 스캔 (Skeleton)"""
        print(f"[{datetime.now()}] Scanning National Law API for: {query}")
        return []

def extract_added_text_from_patch(patch_text: str) -> str:
    """Git diff 패치 텍스트에서 새로 추가된(실질 법령 개정) 라인들만 정제하여 추출"""
    if not patch_text:
        return ""
    added_lines = []
    for line in patch_text.split('\n'):
        if line.startswith('+') and not line.startswith('+++'):
            cleaned = line[1:].strip()
            # 마크다운 헤더 기호만 있거나 무의미한 빈 줄은 제외하고 실질적인 법 조문 텍스트만 모음
            if cleaned and not cleaned.startswith('#'):
                added_lines.append(cleaned)
    return "\n".join(added_lines)

    def scan_legalize_kr_github_api(self):
        """GitHub API를 통해 저장소의 최신 변경 사항 감지 및 RAG 벡터 DB 자동 적재"""
        print(f"[{datetime.now()}] Scanning GitHub API: {self.github_repo}")
        try:
            repo = self.gh.get_repo(self.github_repo)
            # 마지막 5개의 커밋 확인
            commits = repo.get_commits()[:5]
            new_changes = []

            for commit in commits:
                content_id = commit.sha
                if not r.exists(f"law_scan:gh:{content_id}"):
                    files = []
                    # 변경된 파일별로 패치를 분석하여 실질적 개정 텍스트 추출 및 임베딩 적재
                    for file in commit.files:
                        files.append(file.filename)
                        if file.filename.endswith('.md') and file.patch:
                            added_text = extract_added_text_from_patch(file.patch)
                            if added_text:
                                metadata = {
                                    "source": "GitHub (legalize-kr)",
                                    "sha": commit.sha,
                                    "filename": file.filename,
                                    "commit_message": commit.commit.message.split('\n')[0],
                                    "url": commit.html_url
                                }
                                # 벡터스토어 적재 파이프라인 연동
                                try:
                                    from rag_engine import add_document_to_vector_store
                                    add_document_to_vector_store(added_text, metadata)
                                except Exception as ve:
                                    print(f"[{datetime.now()}] Failed to load to vector DB: {ve}")

                    change_item = {
                        "title": commit.commit.message.split('\n')[0],
                        "sha": commit.sha,
                        "url": commit.html_url,
                        "files": files,
                        "source": "GitHub (legalize-kr)"
                    }
                    new_changes.append(change_item)
                    r.setex(f"law_scan:gh:{content_id}", 2592000, "seen")
                    print(f"New GitHub commit found & processed: {change_item['title']}")
            return new_changes
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

if __name__ == "__main__":
    scanner = LawScanner()
    new_laws = scanner.run_all_scanners()
    print(f"Found {len(new_laws)} new law changes.")
