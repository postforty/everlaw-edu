@echo off
chcp 65001 > nul
title Everlaw Edu Server Runner
echo ===================================================
echo  Starting Everlaw Edu Server (Spring Boot)
echo ===================================================

REM ---------------------------------------------------
REM [Settings] Set environment variables for the application
REM ---------------------------------------------------

REM Java Settings (Replace with your JDK path)
set "JAVA_HOME=C:\path\to\your\jdk"
set "PATH=%JAVA_HOME%\bin;%PATH%"

REM JWT Secret (Must be Base64 encoded and at least 32 bytes)
set JWT_SECRET=YOUR_BASE64_ENCODED_JWT_SECRET_HERE
set JWT_EXPIRATION=86400000

REM Database Settings (Connects to pgvector container in docker-compose.yml)
set DB_HOST=localhost
set DB_PORT=5437
set DB_NAME=everlaw_db
set DB_USER=user
set DB_PASSWORD=password
set JPA_DDL_AUTO=update

REM Cache and Queue Settings (Connects to redis container in docker-compose.yml)
set REDIS_HOST=localhost
set REDIS_PORT=6384

REM AI Engine Server URL
set AI_ENGINE_URL=http://localhost:8000

REM Google OAuth2 Client ID (Replace with your Google Client ID)
set GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID_HERE.apps.googleusercontent.com

echo [INFO] Environment variables configured.
echo [INFO] JWT_SECRET injected. (Temporary dev key)
echo [INFO] Database URL: %DB_HOST%:%DB_PORT%/%DB_NAME%
echo [INFO] Redis URL: %REDIS_HOST%:%REDIS_PORT%
echo [INFO] AI Engine URL: %AI_ENGINE_URL%
echo [INFO] Google Client ID configured.
echo.

REM ---------------------------------------------------
REM [Run] Move to the batch file directory and run Gradlew
REM ---------------------------------------------------
echo [INFO] Moving to batch file directory...
cd /d "%~dp0"

echo [INFO] Cleaning previous build outputs...
call gradlew.bat clean

echo [INFO] Starting Spring Boot server (bootRun)...
call gradlew.bat bootRun

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] An error occurred while starting the server.
    pause
    exit /b %ERRORLEVEL%
)

pause
