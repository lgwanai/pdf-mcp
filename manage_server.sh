#!/bin/bash

# PDF MCP Server Management Script
# 用于启动、暂停、停止 PDF MCP 服务器

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDFILE="$SCRIPT_DIR/.server.pid"
LOGFILE="$SCRIPT_DIR/server.log"

# 加载环境变量
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "警告: .env 文件不存在，使用默认配置"
    MCP_PORT=${MCP_PORT:-8000}
    MCP_HOST=${MCP_HOST:-127.0.0.1}
fi

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 检查服务是否运行
check_server_status() {
    if [ -f "$PIDFILE" ]; then
        local pid=$(cat "$PIDFILE")
        if ps -p $pid > /dev/null 2>&1; then
            return 0  # 服务正在运行
        else
            rm -f "$PIDFILE"  # 清理无效的PID文件
            return 1  # 服务未运行
        fi
    else
        return 1  # 服务未运行
    fi
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if lsof -i :$port > /dev/null 2>&1; then
        return 0  # 端口被占用
    else
        return 1  # 端口空闲
    fi
}

# 启动服务
start_server() {
    print_message $BLUE "正在启动 PDF MCP 服务器..."
    
    # 检查服务是否已经运行
    if check_server_status; then
        local pid=$(cat "$PIDFILE")
        print_message $YELLOW "服务器已经在运行中 (PID: $pid)"
        return 0
    fi
    
    # 检查端口是否被占用
    if check_port $MCP_PORT; then
        print_message $RED "错误: 端口 $MCP_PORT 已被占用"
        print_message $YELLOW "请检查是否有其他服务使用该端口，或修改 .env 文件中的 MCP_PORT 配置"
        return 1
    fi
    
    # 检查依赖
    if ! command -v python3 &> /dev/null; then
        print_message $RED "错误: 未找到 python3"
        return 1
    fi
    
    # 检查源文件
    if [ ! -f "$SCRIPT_DIR/src/pdf_mcp_server.py" ]; then
        print_message $RED "错误: 未找到服务器文件 src/pdf_mcp_server.py"
        return 1
    fi
    
    # 启动服务器
    cd "$SCRIPT_DIR"
    nohup python3 src/pdf_mcp_server.py --sse > "$LOGFILE" 2>&1 &
    local server_pid=$!
    
    # 保存PID
    echo $server_pid > "$PIDFILE"
    
    # 等待服务启动
    sleep 3
    
    # 验证服务是否成功启动
    if check_server_status; then
        print_message $GREEN "✓ 服务器启动成功!"
        print_message $BLUE "  PID: $server_pid"
        print_message $BLUE "  端口: $MCP_PORT"
        print_message $BLUE "  URL: http://$MCP_HOST:$MCP_PORT/sse/"
        print_message $BLUE "  日志文件: $LOGFILE"
    else
        print_message $RED "✗ 服务器启动失败"
        print_message $YELLOW "请查看日志文件: $LOGFILE"
        rm -f "$PIDFILE"
        return 1
    fi
}

# 停止服务
stop_server() {
    print_message $BLUE "正在停止 PDF MCP 服务器..."
    
    if ! check_server_status; then
        print_message $YELLOW "服务器未运行"
        return 0
    fi
    
    local pid=$(cat "$PIDFILE")
    
    # 尝试优雅停止
    kill $pid 2>/dev/null
    
    # 等待进程结束
    local count=0
    while [ $count -lt 10 ] && ps -p $pid > /dev/null 2>&1; do
        sleep 1
        count=$((count + 1))
    done
    
    # 如果进程仍在运行，强制杀死
    if ps -p $pid > /dev/null 2>&1; then
        print_message $YELLOW "正在强制停止服务器..."
        kill -9 $pid 2>/dev/null
        sleep 1
    fi
    
    # 清理PID文件
    rm -f "$PIDFILE"
    
    if ! ps -p $pid > /dev/null 2>&1; then
        print_message $GREEN "✓ 服务器已停止"
    else
        print_message $RED "✗ 无法停止服务器"
        return 1
    fi
}

# 重启服务
restart_server() {
    print_message $BLUE "正在重启 PDF MCP 服务器..."
    stop_server
    sleep 2
    start_server
}

# 显示服务状态
show_status() {
    print_message $BLUE "PDF MCP 服务器状态:"
    
    if check_server_status; then
        local pid=$(cat "$PIDFILE")
        print_message $GREEN "  状态: 运行中"
        print_message $BLUE "  PID: $pid"
        print_message $BLUE "  端口: $MCP_PORT"
        print_message $BLUE "  URL: http://$MCP_HOST:$MCP_PORT/sse/"
        
        # 显示内存使用情况
        if command -v ps &> /dev/null; then
            local memory=$(ps -o rss= -p $pid 2>/dev/null | awk '{print $1/1024 " MB"}')
            if [ ! -z "$memory" ]; then
                print_message $BLUE "  内存使用: $memory"
            fi
        fi
        
        # 检查端口连接
        if check_port $MCP_PORT; then
            print_message $GREEN "  端口 $MCP_PORT: 可访问"
        else
            print_message $YELLOW "  端口 $MCP_PORT: 无法访问"
        fi
    else
        print_message $RED "  状态: 未运行"
    fi
    
    # 显示日志文件信息
    if [ -f "$LOGFILE" ]; then
        local log_size=$(du -h "$LOGFILE" | cut -f1)
        print_message $BLUE "  日志文件: $LOGFILE ($log_size)"
    fi
}

# 显示日志
show_logs() {
    local lines=${1:-50}
    
    if [ ! -f "$LOGFILE" ]; then
        print_message $YELLOW "日志文件不存在: $LOGFILE"
        return 1
    fi
    
    print_message $BLUE "显示最近 $lines 行日志:"
    echo "----------------------------------------"
    tail -n $lines "$LOGFILE"
    echo "----------------------------------------"
}

# 清理日志
clean_logs() {
    if [ -f "$LOGFILE" ]; then
        > "$LOGFILE"
        print_message $GREEN "✓ 日志文件已清理"
    else
        print_message $YELLOW "日志文件不存在"
    fi
}

# 显示帮助信息
show_help() {
    echo "PDF MCP 服务器管理脚本"
    echo ""
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  start     启动服务器"
    echo "  stop      停止服务器"
    echo "  restart   重启服务器"
    echo "  status    显示服务器状态"
    echo "  logs      显示日志 (默认50行)"
    echo "  clean     清理日志文件"
    echo "  help      显示此帮助信息"
    echo ""
    echo "选项:"
    echo "  logs [数字]  显示指定行数的日志"
    echo ""
    echo "示例:"
    echo "  $0 start          # 启动服务器"
    echo "  $0 status         # 查看状态"
    echo "  $0 logs 100       # 显示最近100行日志"
    echo "  $0 restart        # 重启服务器"
    echo ""
    echo "配置文件: .env"
    echo "日志文件: $LOGFILE"
    echo "PID文件: $PIDFILE"
}

# 主函数
main() {
    case "$1" in
        start)
            start_server
            ;;
        stop)
            stop_server
            ;;
        restart)
            restart_server
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs $2
            ;;
        clean)
            clean_logs
            ;;
        help|--help|-h)
            show_help
            ;;
        "")
            show_help
            ;;
        *)
            print_message $RED "错误: 未知命令 '$1'"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"