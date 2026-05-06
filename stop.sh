#!/usr/bin/env bash
# 停止后台运行的 ComfyUI 进程

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/comfyui.pid"

stop_pid() {
    local pid="$1"
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "进程 $pid 不存在"
        return 1
    fi

    echo "正在停止 ComfyUI (PID: $pid)..."
    kill "$pid" 2>/dev/null || true

    # 最多等待 15 秒让进程优雅退出
    for _ in $(seq 1 15); do
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "ComfyUI 已停止"
            return 0
        fi
        sleep 1
    done

    # 如果进程仍未退出,强制 kill
    echo "进程未优雅退出,强制终止..."
    kill -9 "$pid" 2>/dev/null || true
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        echo "错误: 无法终止进程 $pid"
        return 1
    fi
    echo "ComfyUI 已强制停止"
    return 0
}

if [ -f "$PID_FILE" ]; then
    PID="$(cat "$PID_FILE")"
    if [ -n "$PID" ] && stop_pid "$PID"; then
        rm -f "$PID_FILE"
        exit 0
    fi
    rm -f "$PID_FILE"
fi

# 兜底:通过进程特征查找
echo "PID 文件不存在或进程已退出,尝试通过进程特征查找..."
PIDS="$(pgrep -f "python .*main\.py.*--enable-manager" || true)"
if [ -z "$PIDS" ]; then
    echo "未发现运行中的 ComfyUI 进程"
    exit 0
fi

for pid in $PIDS; do
    stop_pid "$pid" || true
done
