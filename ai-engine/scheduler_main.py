import time
from apscheduler.schedulers.background import BackgroundScheduler
from scanner.law_scanner import LawScanner
from datetime import datetime

def job_scan_laws():
    print(f"[{datetime.now()}] Starting Law Scan Job...")
    scanner = LawScanner()
    new_laws = scanner.run_all_scanners()
    
    if new_laws:
        print(f"[{datetime.now()}] {len(new_laws)} new law(s) detected!")
        # TODO: 알림 발송 또는 백엔드 API 호출 로직 추가
    else:
        print(f"[{datetime.now()}] No new changes found.")

if __name__ == "__main__":
    scheduler = BackgroundScheduler()
    # 1시간마다 스캔 실행 (테스트를 위해 짧게 설정 가능)
    scheduler.add_job(job_scan_laws, 'interval', hours=1)
    
    print("Law Scanner Scheduler started. Press Ctrl+C to exit.")
    scheduler.start()

    try:
        while True:
            time.sleep(2)
    except (KeyboardInterrupt, SystemExit):
        scheduler.shutdown()
