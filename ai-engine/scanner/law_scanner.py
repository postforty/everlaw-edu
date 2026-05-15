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
        self.github_token = os.getenv("GITHUB_TOKEN")
        self.github_owner = os.getenv("GITHUB_REPO_OWNER")
        self.github_repo_name = os.getenv("GITHUB_REPO_NAME")
        
        # GitHub 클라이언트 초기화
        if self.github_token and "your_github_token" not in self.github_token:
            self.gh = Github(self.github_token)
        else:
            self.gh = Github() # Public 리포지토리는 토큰 없이도 가능 (제한적)

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

    def scan_legalize_kr_github_api(self):
        """GitHub API를 통해 legalize-kr 저장소의 최신 변경 사항 감지"""
        print(f"[{datetime.now()}] Scanning GitHub API: {self.github_owner}/{self.github_repo_name}")
        try:
            repo = self.gh.get_repo(f"{self.github_owner}/{self.github_repo_name}")
            # 마지막 5개의 커밋 확인
            commits = repo.get_commits()[:5]
            new_changes = []

            for commit in commits:
                content_id = commit.sha
                if not r.exists(f"law_scan:gh:{content_id}"):
                    files = [f.filename for f in commit.files]
                    change_item = {
                        "title": commit.commit.message.split('\n')[0],
                        "sha": commit.sha,
                        "url": commit.html_url,
                        "files": files,
                        "source": "GitHub (legalize-kr)"
                    }
                    new_changes.append(change_item)
                    r.setex(f"law_scan:gh:{content_id}", 2592000, "seen")
                    print(f"New GitHub commit found: {change_item['title']}")
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
