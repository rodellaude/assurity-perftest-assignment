@echo off
setlocal

REM Generate dynamic timestamp (yyyyMMdd_HHmmss) using PowerShell for locale-independent formatting
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set TIMESTAMP=%%i

if not exist "logs" mkdir "logs"
if exist "report" rmdir /s /q "report"

set RESULT_FILE=logs\assurity_api_performance_test_results_%TIMESTAMP%.csv

echo Running JMeter test...
echo Results CSV: %RESULT_FILE%

call jmeter -n -t assurity_api_testplan.jmx -l "%RESULT_FILE%" -e -o report %*

if %ERRORLEVEL% NEQ 0 (
    echo JMeter execution failed with exit code %ERRORLEVEL%.
    exit /b %ERRORLEVEL%
)

echo.
echo Test complete.
echo Raw results : %RESULT_FILE%
echo HTML report : report\index.html
endlocal
