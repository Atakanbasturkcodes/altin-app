@echo off
setlocal EnableExtensions EnableDelayedExpansion
title TrID Maker - trid.exe

REM ============================================================
REM tridmaker.bat
REM
REM Target folder:
REM   This BAT's own folder (%~dp0)
REM
REM Result:
REM   trid.exe
REM
REM Existing engine:
REM   trid.exe -> trid.backup
REM
REM Failure:
REM   trid.backup -> trid.exe
REM
REM Success:
REM   trid.backup is deleted
REM
REM No PAUSE.
REM ============================================================

set "TARGET=%~dp0"
set "OUT=%TARGET%trid.exe"
set "BACKUP=%TARGET%trid.backup"

set "WORK=%TEMP%\TrIDMaker_%RANDOM%_%RANDOM%"
set "ZIP=%WORK%\trid.zip"
set "EXTRACT=%WORK%\extract"
set "PYFILE="
set "BUILD_PY=%WORK%\trid_build.py"
set "BUILD_OUT=%WORK%\dist\trid.exe"
set "VERSION_FILE=%WORK%\expected_version.txt"
set "PY="

echo.
echo ============================================================
echo                     TrID Maker
echo ============================================================
echo.

REM ------------------------------------------------------------
REM Recover from an interrupted previous update.
REM ------------------------------------------------------------
if not exist "%OUT%" if exist "%BACKUP%" (
    echo [RECOVERY] trid.exe yok, trid.backup bulundu.
    echo [RECOVERY] Eski trid.exe geri getiriliyor...
    move /y "%BACKUP%" "%OUT%" >nul
    if errorlevel 1 goto :FAIL
)

REM If both exist, an old stale backup should not survive.
if exist "%OUT%" if exist "%BACKUP%" (
    del /q "%BACKUP%" >nul 2>&1
)

mkdir "%WORK%" >nul 2>&1
if errorlevel 1 goto :FAIL
mkdir "%EXTRACT%" >nul 2>&1
if errorlevel 1 goto :FAIL

REM ------------------------------------------------------------
REM 1) Download official current TrID source
REM ------------------------------------------------------------
echo [1/7] Resmi TrID ZIP indiriliyor...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri 'https://mark0.net/download/trid.zip' -OutFile '%ZIP%' -UseBasicParsing"

if errorlevel 1 (
    echo [HATA] TrID ZIP indirilemedi.
    goto :FAIL
)

if not exist "%ZIP%" (
    echo [HATA] TrID ZIP bulunamadi.
    goto :FAIL
)

for %%A in ("%ZIP%") do echo [OK] ZIP boyutu: %%~zA byte

REM ------------------------------------------------------------
REM 2) Extract and find trid.py
REM ------------------------------------------------------------
echo.
echo [2/7] ZIP aciliyor...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%EXTRACT%' -Force"

if errorlevel 1 (
    echo [HATA] ZIP acilamadi.
    goto :FAIL
)

for /r "%EXTRACT%" %%F in (trid.py) do (
    if not defined PYFILE set "PYFILE=%%F"
)

if not defined PYFILE (
    echo [HATA] ZIP icinde trid.py bulunamadi.
    goto :FAIL
)

echo [OK] trid.py:
echo      %PYFILE%

REM ------------------------------------------------------------
REM 3) Find Python
REM ------------------------------------------------------------
echo.
echo [3/7] Python araniyor...

set "PATHPY="
for /f "delims=" %%P in ('where python.exe 2^>nul') do (
    if not defined PATHPY set "PATHPY=%%P"
)

if defined PATHPY (
    "%PATHPY%" --version >nul 2>&1
    if not errorlevel 1 (
        set "PY=%PATHPY%"
        echo [OK] PATH: !PY!
        goto :PYTHON_FOUND
    )
)

set "DEFAULT_PY_FOLDER=D:\Python\WPy64-31450\python"
set "DEFAULT_PY=%DEFAULT_PY_FOLDER%\python.exe"

echo [BILGI] PATH'te Python yok.
echo [BILGI] Varsayilan WinPython kontrol ediliyor...

if exist "%DEFAULT_PY%" (
    "%DEFAULT_PY%" --version >nul 2>&1
    if not errorlevel 1 (
        set "PY=%DEFAULT_PY%"
        echo [OK] WinPython: %DEFAULT_PY_FOLDER%\
        goto :PYTHON_FOUND
    )
)

:ASK_PYTHON
echo.
echo Python klasoru bulunamadi.
echo Ornek:
echo   D:\Python\WPy64-31450\python\
echo.
echo NOT: python.exe yazma. Sadece klasor yolunu yaz.
echo.

set "USER_PY_FOLDER="
set /p "USER_PY_FOLDER=Python klasor yolu: "

if not defined USER_PY_FOLDER goto :ASK_PYTHON

set "USER_PY_FOLDER=!USER_PY_FOLDER:"=!"

:TRIM_SLASH
if "!USER_PY_FOLDER:~-1!"=="\" (
    set "USER_PY_FOLDER=!USER_PY_FOLDER:~0,-1!"
    goto :TRIM_SLASH
)

set "USER_PY=!USER_PY_FOLDER!\python.exe"

if not exist "%USER_PY%" (
    echo [HATA] Bu klasorde python.exe yok.
    goto :ASK_PYTHON
)

"%USER_PY%" --version >nul 2>&1
if errorlevel 1 (
    echo [HATA] Bu Python calistirilamiyor.
    goto :ASK_PYTHON
)

set "PY=%USER_PY%"
echo [OK] Python: %USER_PY_FOLDER%\

:PYTHON_FOUND

echo.
"%PY%" --version
if errorlevel 1 goto :FAIL

REM ------------------------------------------------------------
REM Extract expected version from official trid.py.
REM ------------------------------------------------------------
"%PY%" -c "import re,sys; s=open(sys.argv[1],encoding='utf-8').read(); m=re.search(r'(?m)^\s*PROGRAM_VER\s*=\s*""([^""]+)""',s); print(m.group(1) if m else '')" "%PYFILE%" > "%VERSION_FILE%"

if errorlevel 1 goto :FAIL

set "EXPECTED_VER="
set /p "EXPECTED_VER="<"%VERSION_FILE%"

if not defined EXPECTED_VER (
    echo [HATA] trid.py icinden PROGRAM_VER okunamadi.
    goto :FAIL
)

echo [OK] Beklenen TrID surumu: %EXPECTED_VER%

REM ------------------------------------------------------------
REM 4) Required packages
REM ------------------------------------------------------------
echo.
echo [4/7] Paketler kontrol ediliyor...

echo [PyInstaller]
"%PY%" -m PyInstaller --version >nul 2>&1
if errorlevel 1 (
    echo [EKSIK] PyInstaller kuruluyor...
    "%PY%" -m pip install pyinstaller
    if errorlevel 1 goto :FAIL
) else (
    echo [OK] PyInstaller mevcut. Indirme yok.
)

echo [StringZilla]
"%PY%" -c "import stringzilla" >nul 2>&1
if errorlevel 1 (
    echo [EKSIK] StringZilla kuruluyor...
    "%PY%" -m pip install stringzilla
    if errorlevel 1 goto :FAIL
) else (
    echo [OK] StringZilla mevcut. Indirme yok.
)

REM ------------------------------------------------------------
REM 5) Rename current engine to trid.backup BEFORE building.
REM ------------------------------------------------------------
echo.
echo [5/7] Mevcut trid.exe yedekleniyor...

if exist "%OUT%" (
    if exist "%BACKUP%" del /q "%BACKUP%" >nul 2>&1

    move /y "%OUT%" "%BACKUP%" >nul
    if errorlevel 1 (
        echo [HATA] trid.exe -> trid.backup yapilamadi.
        goto :FAIL
    )

    echo [OK] trid.exe -> trid.backup
)

REM ------------------------------------------------------------
REM Build source in TEMP.
REM Disk definition cache is disabled.
REM ------------------------------------------------------------
copy /y "%PYFILE%" "%BUILD_PY%" >nul
if errorlevel 1 goto :ROLLBACK

"%PY%" -c "import base64,sys;exec(base64.b64decode('aW1wb3J0IHN5cyxiYXNlNjQKZnJvbSBwYXRobGliIGltcG9ydCBQYXRoCnA9UGF0aChzeXMuYXJndlsxXSkKcz1wLnJlYWRfdGV4dChlbmNvZGluZz0idXRmLTgiKQpTRVJWRVJfRlVOQz1iYXNlNjQuYjY0ZGVjb2RlKCdaR1ZtSUhSeWFXUmZjMlZ5ZG1WeUtGUkVRaXdnYzNSeWFXNW5ZMmhsWTJzOVZISjFaU2s2Q2lBZ0lDQnpkR1JwYmw5MWRHWTRJRDBnYVc4dVZHVjRkRWxQVjNKaGNIQmxjaWh6ZVhNdWMzUmthVzR1WW5WbVptVnlMQ0JsYm1OdlpHbHVaejBpZFhSbUxUZ2lMQ0JsY25KdmNuTTlJbkpsY0d4aFkyVWlLUW9nSUNBZ2NISnBiblFvSWw5ZlZGSkpSRjlTUlVGRVdWOWZJaXdnWm14MWMyZzlWSEoxWlNrS0lDQWdJR1p2Y2lCeVlYY2dhVzRnYzNSa2FXNWZkWFJtT0RvS0lDQWdJQ0FnSUNCbWFXeGxibUZ0WlNBOUlISmhkeTV5YzNSeWFYQW9JbHh5WEc0aUtRb2dJQ0FnSUNBZ0lHbG1JRzV2ZENCbWFXeGxibUZ0WlRvS0lDQWdJQ0FnSUNBZ0lDQWdZMjl1ZEdsdWRXVUtJQ0FnSUNBZ0lDQnBaaUJtYVd4bGJtRnRaU0E5UFNBaVgxOVVVa2xFWDFGVlNWUmZYeUk2Q2lBZ0lDQWdJQ0FnSUNBZ0lHSnlaV0ZyQ2lBZ0lDQWdJQ0FnY0hKcGJuUW9JbDlmVkZKSlJGOUNSVWRKVGw5Zklpd2dabXgxYzJnOVZISjFaU2tLSUNBZ0lDQWdJQ0JwWmlCdWIzUWdiM011Y0dGMGFDNWxlR2x6ZEhNb1ptbHNaVzVoYldVcE9nb2dJQ0FnSUNBZ0lDQWdJQ0J3Y21sdWRDZ2lSbWxzWlNCdWIzUWdabTkxYm1RaElpd2dabXgxYzJnOVZISjFaU2tLSUNBZ0lDQWdJQ0FnSUNBZ2NISnBiblFvSWw5ZlZGSkpSRjlGVGtSZlh5SXNJR1pzZFhOb1BWUnlkV1VwQ2lBZ0lDQWdJQ0FnSUNBZ0lHTnZiblJwYm5WbENpQWdJQ0FnSUNBZ2RISjVPZ29nSUNBZ0lDQWdJQ0FnSUNCeVpYTjFiSFJ6SUQwZ2RISnBaRUZ1WVd4NWVtVW9abWxzWlc1aGJXVXNJRlJFUWl3Z2MzUnlhVzVuWTJobFkyc3BDaUFnSUNBZ0lDQWdJQ0FnSUdsbUlISmxjM1ZzZEhNNkNpQWdJQ0FnSUNBZ0lDQWdJQ0FnSUNCbWIzSWdjbVZ6SUdsdUlISmxjM1ZzZEhOYk9qVmRPZ29nSUNBZ0lDQWdJQ0FnSUNBZ0lDQWdJQ0FnSUhCeWFXNTBLQ0lsTlM0eFppVWxJQ2d1SlhNcElDVnpJQ2dsYVM4bGFTOGxhU2tpSUNVZ0tBb2dJQ0FnSUNBZ0lDQWdJQ0FnSUNBZ0lDQWdJQ0FnSUNCeVpYTXVjR1Z5WXl3Z2NtVnpMblJ5YVdSa1pXWXVaWGgwTENCeVpYTXVkSEpwWkdSbFppNW1hV3hsZEhsd1pTd0tJQ0FnSUNBZ0lDQWdJQ0FnSUNBZ0lDQWdJQ0FnSUNBZ2NtVnpMbkIwY3l3Z2NtVnpMbkJoZEhRc0lISmxjeTV6ZEhJcExDQm1iSFZ6YUQxVWNuVmxLUW9nSUNBZ0lDQWdJQ0FnSUNCbGJITmxPZ29nSUNBZ0lDQWdJQ0FnSUNBZ0lDQWdjSEpwYm5Rb0lsVnVhMjV2ZDI0aElpd2dabXgxYzJnOVZISjFaU2tLSUNBZ0lDQWdJQ0JsZUdObGNIUWdSWGhqWlhCMGFXOXVJR0Z6SUdWeWNqb0tJQ0FnSUNBZ0lDQWdJQ0FnY0hKcGJuUW9Ja1ZTVWs5U09pQWlJQ3NnYzNSeUtHVnljaWtzSUdac2RYTm9QVlJ5ZFdVcENpQWdJQ0FnSUNBZ2NISnBiblFvSWw5ZlZGSkpSRjlGVGtSZlh5SXNJR1pzZFhOb1BWUnlkV1VwQ2c9PScpLmRlY29kZSgidXRmLTgiKQppZiAnZGVzdD0ic2VydmVyIicgbm90IGluIHM6CiAgICBtYXJrZXI9IiAgICByZXMgPSBwYXJzZXIucGFyc2VfYXJncygpIgogICAgaW5zZXJ0PSgnICAgIHBhcnNlci5hZGRfYXJndW1lbnQoIi0tc2VydmVyIiwgYWN0aW9uPSJzdG9yZV90cnVlIiwgZGVzdD0ic2VydmVyIiwgZGVmYXVsdD1GYWxzZSxcbicKICAgICAgICAgICAgJyAgICAgICAgICAgICAgICAgICAgICAgIGhlbHA9ImtlZXAgdGhlIFRySUQgZW5naW5lIHJ1bm5pbmcgYW5kIHJlYWQgZmlsZXMgZnJvbSBzdGRpbiIpXG4nKQogICAgaWYgbWFya2VyIGluIHM6CiAgICAgICAgcz1zLnJlcGxhY2UobWFya2VyLGluc2VydCttYXJrZXIsMSkKICAgIGVsc2U6CiAgICAgICAgbGluZXM9cy5zcGxpdGxpbmVzKFRydWUpCiAgICAgICAgaWR4PW5leHQoKGkgZm9yIGksbCBpbiBlbnVtZXJhdGUobGluZXMpIGlmICJwYXJzZXIucGFyc2VfYXJncygpIiBpbiBsKSwtMSkKICAgICAgICBpZiBpZHg8MDogcmFpc2UgU3lzdGVtRXhpdCgiVHJJRCBwYXJzZXIgbWFya2VyIG5vdCBmb3VuZCIpCiAgICAgICAgbGluZXMuaW5zZXJ0KGlkeCxpbnNlcnQpCiAgICAgICAgcz0iIi5qb2luKGxpbmVzKQppZiAiZGVmIHRyaWRfc2VydmVyKCIgbm90IGluIHM6CiAgICBtYXJrZXI9ImRlZiBnZXRfdW5pcXVlX2ZpbGVuYW1lKHBhdGgpOiIKICAgIHBvcz1zLmZpbmQobWFya2VyKQogICAgaWYgcG9zPDA6IHJhaXNlIFN5c3RlbUV4aXQoIlRySUQgZnVuY3Rpb24gbWFya2VyIG5vdCBmb3VuZCIpCiAgICBzPXNbOnBvc10rU0VSVkVSX0ZVTkMrIlxuIitzW3BvczpdCnM9cy5yZXBsYWNlKCJUREIgPSB0cmRwa2cyZGVmcyh0cmRmaWxlbmFtZSwgdXNlY2FjaGU9VHJ1ZSkiLCJUREIgPSB0cmRwa2cyZGVmcyh0cmRmaWxlbmFtZSwgdXNlY2FjaGU9RmFsc2UpIiwxKQppZiAiaWYgcGFyYW1zLnNlcnZlcjoiIG5vdCBpbiBzOgogICAgbmVlZGxlPSIgICAgaWYgcGFyYW1zLnVwZGF0ZTpcbiAgICAgICAgdHJpZF91cGRhdGUodHJkZmlsZW5hbWUpXG5cbiIKICAgIGlmIG5lZWRsZSBub3QgaW4gczogcmFpc2UgU3lzdGVtRXhpdCgiVHJJRCB1cGRhdGUgbWFya2VyIG5vdCBmb3VuZCIpCiAgICBicmFuY2g9KAogICAgICAgICIgICAgaWYgcGFyYW1zLnVwZGF0ZTpcbiIKICAgICAgICAiICAgICAgICB0cmlkX3VwZGF0ZSh0cmRmaWxlbmFtZSlcblxuIgogICAgICAgICIgICAgIyBQZXJzaXN0ZW50IEdVSSBzZXJ2ZXIgbW9kZSBNVVNUIGJlIGhhbmRsZWQgYmVmb3JlIHRoZSBub3JtYWwgZmlsZS1saXN0IGNoZWNrLlxuIgogICAgICAgICIgICAgaWYgcGFyYW1zLnNlcnZlcjpcbiIKICAgICAgICAiICAgICAgICBpZiBub3Qgb3MucGF0aC5leGlzdHModHJkZmlsZW5hbWUpOlxuIgogICAgICAgICIgICAgICAgICAgICBlcnJwcmludChmXCJJL08gRXJyb3I6IGZpbGUge3RyZGZpbGVuYW1lfSBub3QgZm91bmQuXCIpXG4iCiAgICAgICAgIiAgICAgICAgICAgIHN5cy5leGl0KDEpXG4iCiAgICAgICAgIiAgICAgICAgcHJpbnQoXCJMb2FkaW5nIGRlZmluaXRpb25zIGZyb20gZmlsZTpcIiwgdHJkZmlsZW5hbWUpXG4iCiAgICAgICAgIiAgICAgICAgVERCID0gdHJkcGtnMmRlZnModHJkZmlsZW5hbWUsIHVzZWNhY2hlPUZhbHNlKVxuIgogICAgICAgICIgICAgICAgIHByaW50KFwiRGVmaW5pdGlvbnMgZm91bmQ6XCIsIFREQi5kZWZzX251bSlcbiIKICAgICAgICAiICAgICAgICBzdHJpbmdjaGVjayA9IFRydWUgaWYgbm90IHBhcmFtcy5ub3N0ciBlbHNlIEZhbHNlXG4iCiAgICAgICAgIiAgICAgICAgdHJpZF9zZXJ2ZXIoVERCLCBzdHJpbmdjaGVjaylcbiIKICAgICAgICAiICAgICAgICBzeXMuZXhpdCgwKVxuXG4iCiAgICApCiAgICBzPXMucmVwbGFjZShuZWVkbGUsYnJhbmNoLDEpCnAud3JpdGVfdGV4dChzLGVuY29kaW5nPSJ1dGYtOCIpCg=='))" "%BUILD_PY%"
if errorlevel 1 (
    echo [HATA] TrID kaynak patch islemi basarisiz.
    goto :ROLLBACK
)

echo [OK] Server/cache patch basarili.

"%PY%" -m PyInstaller ^
    --noconfirm ^
    --onefile ^
    --console ^
    --name trid ^
    --distpath "%WORK%\dist" ^
    --workpath "%WORK%\builddir" ^
    --specpath "%WORK%\specdir" ^
    --collect-all stringzilla ^
    "%BUILD_PY%"

if errorlevel 1 (
    echo [HATA] PyInstaller build basarisiz.
    goto :ROLLBACK
)

if not exist "%BUILD_OUT%" (
    echo [HATA] Yeni trid.exe olusturulamadi.
    goto :ROLLBACK
)

REM ------------------------------------------------------------
REM Test TEMP build with -v and verify expected version.
REM ------------------------------------------------------------
echo.
echo [6/7] Yeni trid.exe kontrol ediliyor...

"%BUILD_OUT%" -v > "%WORK%\version.txt" 2>&1
if errorlevel 1 (
    echo [HATA] Yeni trid.exe -v testi basarisiz.
    goto :ROLLBACK
)

findstr /i /c:"v%EXPECTED_VER%" "%WORK%\version.txt" >nul
if errorlevel 1 (
    echo [HATA] Yeni EXE beklenen surumu vermiyor.
    echo [BILGI] Beklenen: %EXPECTED_VER%
    goto :ROLLBACK
)

echo [OK] Yeni EXE surumu dogrulandi: %EXPECTED_VER%

REM If definitions exist, verify the persistent --server mode too.
if exist "%TARGET%TrIDDefs.TRD" (
    echo [BILGI] Server modu test ediliyor...
    >"%WORK%\server_input.txt" echo __TRID_QUIT__
    "%BUILD_OUT%" --server -d "%TARGET%TrIDDefs.TRD" < "%WORK%\server_input.txt" > "%WORK%\server_test.txt" 2>&1
    if errorlevel 1 (
        echo [HATA] Server modu baslatilamadi.
        goto :ROLLBACK
    )
    findstr /c:"__TRID_READY__" "%WORK%\server_test.txt" >nul
    if errorlevel 1 (
        echo [HATA] Server READY mesaji alinmadi.
        goto :ROLLBACK
    )
    echo [OK] Server modu calisiyor.
)

REM Move new EXE to the target folder.
move /y "%BUILD_OUT%" "%OUT%" >nul
if errorlevel 1 (
    echo [HATA] Yeni trid.exe hedef klasore tasinamadi.
    goto :ROLLBACK
)

REM Test the actual final file.
"%OUT%" -v > "%WORK%\final_version.txt" 2>&1
if errorlevel 1 goto :ROLLBACK_FINAL

findstr /i /c:"v%EXPECTED_VER%" "%WORK%\final_version.txt" >nul
if errorlevel 1 goto :ROLLBACK_FINAL

if exist "%TARGET%TrIDDefs.TRD" (
    echo [BILGI] Nihai server modu tekrar test ediliyor...
    >"%WORK%\server_input_final.txt" echo __TRID_QUIT__
    "%OUT%" --server -d "%TARGET%TrIDDefs.TRD" < "%WORK%\server_input_final.txt" > "%WORK%\server_test_final.txt" 2>&1
    if errorlevel 1 goto :ROLLBACK_FINAL
    findstr /c:"__TRID_READY__" "%WORK%\server_test_final.txt" >nul
    if errorlevel 1 goto :ROLLBACK_FINAL
)

REM Success: old backup is no longer needed.
if exist "%BACKUP%" del /q "%BACKUP%" >nul 2>&1
if exist "%WORK%" rmdir /s /q "%WORK%" >nul 2>&1

REM Remove old cache names if they were left by an older build.
del /q "%TARGET%.triddefs.trd.cache" >nul 2>&1
del /q "%TARGET%.TrIDDefs.TRD.cache" >nul 2>&1

echo.
echo ============================================================
echo                     BASARILI
echo ============================================================
echo TrID surumu: %EXPECTED_VER%
echo Sonuc:       %OUT%
echo.
exit /b 0

:ROLLBACK_FINAL
echo [HATA] Nihai trid.exe kontrolu basarisiz.
del /q "%OUT%" >nul 2>&1

:ROLLBACK
echo.
echo [ROLLBACK] Eski trid.exe geri getiriliyor...

if exist "%BACKUP%" (
    if exist "%OUT%" del /q "%OUT%" >nul 2>&1
    move /y "%BACKUP%" "%OUT%" >nul
    if errorlevel 1 (
        echo [KRITIK] trid.backup geri yuklenemedi.
        goto :FAIL_NO_RESTORE
    )
    echo [OK] Eski trid.exe geri getirildi.
)

if exist "%WORK%" rmdir /s /q "%WORK%" >nul 2>&1

echo.
echo ============================================================
echo                 GUNCELLEME BASARISIZ
echo ============================================================
echo Eski trid.exe geri yuklendi.
echo.
exit /b 1

:FAIL
if exist "%WORK%" rmdir /s /q "%WORK%" >nul 2>&1
echo.
echo ============================================================
echo                      ISLEM BASARISIZ
echo ============================================================
echo.
exit /b 1

:FAIL_NO_RESTORE
if exist "%WORK%" rmdir /s /q "%WORK%" >nul 2>&1
echo.
echo ============================================================
echo                  KRITIK ISLEM BASARISIZ
echo ============================================================
echo trid.exe ve trid.backup durumunu kontrol et.
echo.
exit /b 2
