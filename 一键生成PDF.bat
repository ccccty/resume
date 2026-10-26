@echo off
chcp 65001 >nul
setlocal
set "HTML=%~dp0resume-print.html"
set "PDF=%~dp0assets\resume.pdf"
set "URL=file:///%HTML:\=/%"

set "BROWSER="
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" set "BROWSER=C:\Program Files\Google\Chrome\Application\chrome.exe"
if defined BROWSER goto run
if exist "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" set "BROWSER=C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if defined BROWSER goto run
if exist "C:\Program Files\Microsoft\Edge\Application\msedge.exe" set "BROWSER=C:\Program Files\Microsoft\Edge\Application\msedge.exe"
if defined BROWSER goto run

echo [ERROR] Chrome or Edge not found. Please install one of them.
pause
exit /b 1

:run
echo Generating PDF from resume-print.html ...
echo.
"%BROWSER%" --headless=new --disable-gpu --no-pdf-header-footer --print-to-pdf="%PDF%" "%URL%"
echo.
if exist "%PDF%" (
  echo [OK] assets\resume.pdf has been updated.
) else (
  echo [FAILED] PDF was not created. Please check the file resume-print.html.
)
echo.
pause
