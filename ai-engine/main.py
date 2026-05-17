import os
import sys
from contextlib import asynccontextmanager
from fastapi import FastAPI
from apscheduler.schedulers.background import BackgroundScheduler
from datetime import datetime

# ai-engine 폴더 참조 추가 (import 경로 보장)
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.ingestion.scheduler import LawScanner
from app.api.v1.endpoints import router as api_router

# =====================================================================
# FastAPI Lifespan Context Manager (SaaS 원스톱 통합)
# =====================================================================

def job_scan_laws():
    """백그라운드에서 주기적으로 국가 법령 RSS 및 GitHub API를 상시 모니터링하여 벡터 DB 자동 Upsert"""
    print(f"⏰ [{datetime.now()}] --- [STARTING BACKGROUND LAW SCAN JOB (REFACTORED)] ---")
    try:
        scanner = LawScanner()
        new_laws = scanner.run_all_scanners()
        print(f"✅ [{datetime.now()}] --- [LAW SCAN COMPLETE: {len(new_laws)} new law(s) detected] ---")
    except Exception as e:
        print(f"❌ [{datetime.now()}] --- [BACKGROUND LAW SCAN FAILED: {str(e)}] ---")

@asynccontextmanager
async def lifespan(app: FastAPI):
    import threading
    # [Startup Event]: FastAPI 서버 기동 즉시 백그라운드 스케줄러 연동 개시
    scheduler = BackgroundScheduler()
    # 1시간마다 실시간 스캐너 실행 (배경 데몬)
    scheduler.add_job(job_scan_laws, 'interval', hours=1)
    scheduler.start()
    print("🚀 [성공] FastAPI AI Engine 구동 완료 및 실시간 법률 스캐너 백그라운드 연동 개시!")
    
    # 즉시 테스트용 첫 1회 스캔 실행 (최초 구동 시 즉시 데이터 임베딩 적재 및 신선도 세팅 - Uvicorn 블로킹 방지를 위해 백그라운드 스레드로 비동기 기동)
    threading.Thread(target=job_scan_laws, daemon=True).start() 

    yield # FastAPI 서버가 기동을 유지하며 API 요청을 동기 서빙하는 영역

    # [Shutdown Event]: FastAPI 서버 정상 종료 시 스케줄러를 Graceful하게 자원 해제
    scheduler.shutdown()
    print("🛑 백그라운드 스케줄러 스레드 안전하게 해제 완료 (Graceful Shutdown)")

# Lifespan이 접합된 FastAPI 앱 기동
app = FastAPI(
    title="EverLaw Edu AI Engine",
    description="최신 법령 DB를 지식의 원천으로 삼아 교육 콘텐츠를 자율 생산하고 검증하는 차세대 컴플라이언스 AI 엔진 (Refactored Ingestion-Serving Architecture)",
    version="0.2.0",
    lifespan=lifespan
)

# API 엔드포인트 라우터 연결
app.include_router(api_router, prefix="/api/v1")

# 📢 [FastAPI Route Table Dumper] 기동 시 마운트된 모든 API 경로 목록을 콘솔에 덤프 출력
print("📢 [FastAPI Route Table] 마운트된 모든 API 경로 목록:")
for route in app.routes:
    methods = route.methods if hasattr(route, 'methods') else "GET"
    print(f"   👉 [{methods}] {route.path}")

from fastapi import Request

@app.middleware("http")
async def log_requests(request: Request, call_next):
    print(f"📡 [서버 유입 요청 포착] Method: {request.method} | URL: {request.url}", flush=True)
    response = await call_next(request)
    print(f"📡 [서버 응답 결과 송출] Status Code: {response.status_code}", flush=True)
    return response

@app.get("/")
async def root():
    return {
        "message": "EverLaw Edu AI Engine is running",
        "version": "0.2.0",
        "scheduler_status": "Active & Running in Background"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
