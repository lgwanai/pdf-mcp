@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM PDF MCP Server Management Script for Windows
REM 用于启动、暂停、停止 PDF MCP 服务器

set "SCRIPT_DIR=%~dp0"
set "PIDFILE=%SCRIPT_DIR%.server.pid"
set "LOGFILE=%SCRIPT_DIR%server.log"

REM 加载环境变量
if exist "%SCRIPT_DIR%.env" (
    for /f "usebackq tokens=1,2 delims==" %%a in ("%SCRIPT_DIR%.env") do (
        if not "%%a"=="" if not "%%a:~0,1"=="#" (
            set "%%a=%%b"
        )
    )
) else (
    echo 警告: .env 文件不存在，使用默认配置
    if not defined MCP_PORT set "MCP_PORT=8000"
    if not defined MCP_HOST set "MCP_HOST=127.0.0.1"
)

REM 颜色定义（Windows 10及以上支持ANSI转义序列）
set "RED=[31m"
set "GREEN=[32m"
set "YELLOW=[33m"
set "BLUE=[34m"
set "NC=[0m"

REM 打印带颜色的消息
:print_message
echo %~1%~2%NC%
goto :eof

REM 检查服务是否运行
:check_server_status
if not exist "%PIDFILE%" (
    exit /b 1
)
set /p PID=<"%PIDFILE%"
tasklist /fi "PID eq %PID%" 2>nul | find "%PID%" >nul
if errorlevel 1 (
    del "%PIDFILE%" 2>nul
    exit /b 1
)
exit /b 0

REM 检查端口是否被占用
:check_port
netstat -an | find ":%~1 " >nul
exit /b %errorlevel%

REM 启动服务
:start_server
call :print_message "%BLUE%" "正在启动 PDF MCP 服务器..."

REM 检查服务是否已经运行
call :check_server_status
if not errorlevel 1 (
    set /p PID=<"%PIDFILE%"
    call :print_message "%YELLOW%" "服务器已经在运行中 (PID: !PID!)"
    goto :eof
)

REM 检查端口是否被占用
call :check_port %MCP_PORT%
if not errorlevel 1 (
    call :print_message "%RED%" "错误: 端口 %MCP_PORT% 已被占用"
    call :print_message "%YELLOW%" "请检查是否有其他服务使用该端口，或修改 .env 文件中的 MCP_PORT 配置"
    goto :eof
)

REM 检查依赖
python --version >nul 2>&1
if errorlevel 1 (
    call :print_message "%RED%" "错误: 未找到 python"
    goto :eof
)

REM 检查源文件
if not exist "%SCRIPT_DIR%src\pdf_mcp_server.py" (
    call :print_message "%RED%" "错误: 未找到服务器文件 src\pdf_mcp_server.py"
    goto :eof
)

REM 启动服务器
cd /d "%SCRIPT_DIR%"
start /b python src\pdf_mcp_server.py --sse >"%LOGFILE%" 2>&1

REM 获取进程ID（Windows下比较复杂，使用wmic）
for /f "tokens=2" %%i in ('wmic process where "commandline like '%%pdf_mcp_server.py%%'" get processid /value ^| find "ProcessId"') do (
    set "SERVER_PID=%%i"
)

REM 保存PID
echo !SERVER_PID! > "%PIDFILE%"

REM 等待服务启动
timeout /t 3 /nobreak >nul

REM 验证服务是否成功启动
call :check_server_status
if not errorlevel 1 (
    call :print_message "%GREEN%" "✓ 服务器启动成功!"
    call :print_message "%BLUE%" "  PID: !SERVER_PID!"
    call :print_message "%BLUE%" "  端口: %MCP_PORT%"
    call :print_message "%BLUE%" "  URL: http://%MCP_HOST%:%MCP_PORT%/sse/"
    call :print_message "%BLUE%" "  日志文件: %LOGFILE%"
) else (
    call :print_message "%RED%" "✗ 服务器启动失败"
    call :print_message "%YELLOW%" "请查看日志文件: %LOGFILE%"
    del "%PIDFILE%" 2>nul
)
goto :eof

REM 停止服务
:stop_server
call :print_message "%BLUE%" "正在停止 PDF MCP 服务器..."

call :check_server_status
if errorlevel 1 (
    call :print_message "%YELLOW%" "服务器未运行"
    goto :eof
)

set /p PID=<"%PIDFILE%"

REM 尝试优雅停止
taskkill /pid %PID% >nul 2>&1

REM 等待进程结束
set "count=0"
:wait_loop
if !count! geq 10 goto force_kill
tasklist /fi "PID eq %PID%" 2>nul | find "%PID%" >nul
if errorlevel 1 goto cleanup
timeout /t 1 /nobreak >nul
set /a count+=1
goto wait_loop

:force_kill
tasklist /fi "PID eq %PID%" 2>nul | find "%PID%" >nul
if not errorlevel 1 (
    call :print_message "%YELLOW%" "正在强制停止服务器..."
    taskkill /f /pid %PID% >nul 2>&1
    timeout /t 1 /nobreak >nul
)

:cleanup
REM 清理PID文件
del "%PIDFILE%" 2>nul

tasklist /fi "PID eq %PID%" 2>nul | find "%PID%" >nul
if errorlevel 1 (
    call :print_message "%GREEN%" "✓ 服务器已停止"
) else (
    call :print_message "%RED%" "✗ 无法停止服务器"
)
goto :eof

REM 重启服务
:restart_server
call :print_message "%BLUE%" "正在重启 PDF MCP 服务器..."
call :stop_server
timeout /t 2 /nobreak >nul
call :start_server
goto :eof

REM 显示服务状态
:show_status
call :print_message "%BLUE%" "PDF MCP 服务器状态:"

call :check_server_status
if not errorlevel 1 (
    set /p PID=<"%PIDFILE%"
    call :print_message "%GREEN%" "  状态: 运行中"
    call :print_message "%BLUE%" "  PID: !PID!"
    call :print_message "%BLUE%" "  端口: %MCP_PORT%"
    call :print_message "%BLUE%" "  URL: http://%MCP_HOST%:%MCP_PORT%/sse/"
    
    REM 显示内存使用情况
    for /f "tokens=5" %%i in ('tasklist /fi "PID eq !PID!" /fo table ^| find "!PID!"') do (
        call :print_message "%BLUE%" "  内存使用: %%i"
    )
    
    REM 检查端口连接
    call :check_port %MCP_PORT%
    if not errorlevel 1 (
        call :print_message "%GREEN%" "  端口 %MCP_PORT%: 可访问"
    ) else (
        call :print_message "%YELLOW%" "  端口 %MCP_PORT%: 无法访问"
    )
) else (
    call :print_message "%RED%" "  状态: 未运行"
)

REM 显示日志文件信息
if exist "%LOGFILE%" (
    for %%i in ("%LOGFILE%") do (
        call :print_message "%BLUE%" "  日志文件: %LOGFILE% (%%~zi bytes)"
    )
)
goto :eof

REM 显示日志
:show_logs
set "lines=%~1"
if "%lines%"=="" set "lines=50"

if not exist "%LOGFILE%" (
    call :print_message "%YELLOW%" "日志文件不存在: %LOGFILE%"
    goto :eof
)

call :print_message "%BLUE%" "显示最近 %lines% 行日志:"
echo ----------------------------------------
REM Windows下没有tail命令，使用PowerShell实现
powershell -command "Get-Content '%LOGFILE%' -Tail %lines%"
echo ----------------------------------------
goto :eof

REM 清理日志
:clean_logs
if exist "%LOGFILE%" (
    echo. > "%LOGFILE%"
    call :print_message "%GREEN%" "✓ 日志文件已清理"
) else (
    call :print_message "%YELLOW%" "日志文件不存在"
)
goto :eof

REM 显示帮助信息
:show_help
echo PDF MCP 服务器管理脚本 (Windows版)
echo.
echo 用法: %~nx0 [命令] [选项]
echo.
echo 命令:
echo   start     启动服务器
echo   stop      停止服务器
echo   restart   重启服务器
echo   status    显示服务器状态
echo   logs      显示日志 (默认50行)
echo   clean     清理日志文件
echo   help      显示此帮助信息
echo.
echo 选项:
echo   logs [数字]  显示指定行数的日志
echo.
echo 示例:
echo   %~nx0 start          # 启动服务器
echo   %~nx0 status         # 查看状态
echo   %~nx0 logs 100       # 显示最近100行日志
echo   %~nx0 restart        # 重启服务器
echo.
echo 配置文件: .env
echo 日志文件: %LOGFILE%
echo PID文件: %PIDFILE%
goto :eof

REM 主函数
if "%~1"=="" goto show_help
if "%~1"=="start" goto start_server
if "%~1"=="stop" goto stop_server
if "%~1"=="restart" goto restart_server
if "%~1"=="status" goto show_status
if "%~1"=="logs" (
    call :show_logs %~2
    goto :eof
)
if "%~1"=="clean" goto clean_logs
if "%~1"=="help" goto show_help
if "%~1"=="--help" goto show_help
if "%~1"=="-h" goto show_help

call :print_message "%RED%" "错误: 未知命令 '%~1'"
echo.
goto show_help