#!/usr/bin/env bash
# 在后台使用 .venv 虚拟环境启动 ComfyUI (python main.py --enable-manager)

set -e

# 脚本所在目录即为 ComfyUI 根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VENV_DIR="$SCRIPT_DIR/.venv"
PID_FILE="$SCRIPT_DIR/comfyui.pid"
LOG_FILE="$SCRIPT_DIR/comfyui.log"

# 检查虚拟环境是否存在
if [ ! -f "$VENV_DIR/bin/activate" ]; then
    echo "错误: 虚拟环境不存在于 $VENV_DIR"
    echo "请先创建虚拟环境: python -m venv .venv"
    exit 1
fi

# 检查是否已经运行
if [ -f "$PID_FILE" ]; then
    OLD_PID="$(cat "$PID_FILE")"
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "ComfyUI 已在运行 (PID: $OLD_PID)"
        exit 0
    else
        echo "发现陈旧的 PID 文件,正在清理..."
        rm -f "$PID_FILE"
    fi
fi

# 激活虚拟环境
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

# AWS Neuron (Inferentia/Trainium) runtime configuration.
# 这些变量只在检测到 /dev/neuron* 时启用,其他环境下是无害的 no-op。
if ls /dev/neuron* >/dev/null 2>&1; then
    export PJRT_DEVICE=NEURON
    export NEURON_RT_VISIBLE_CORES=${NEURON_RT_VISIBLE_CORES:-0-1}
    export NEURONX_CACHE=on
    export NEURON_COMPILE_CACHE_URL="${NEURON_COMPILE_CACHE_URL:-$SCRIPT_DIR/.neuron_cache}"
    export NEURON_FUSE_SOFTMAX=1
    export NEURON_CC_FLAGS="${NEURON_CC_FLAGS:---auto-cast matmul --auto-cast-type bf16 --model-type=unet-inference}"
    mkdir -p "$NEURON_COMPILE_CACHE_URL"
    EXTRA_ARGS=(--neuron)
else
    EXTRA_ARGS=()
fi

echo "正在后台启动 ComfyUI..."
# 使用 nohup + setsid 确保终端关闭后进程继续运行
nohup python main.py --enable-manager "${EXTRA_ARGS[@]}" "$@" > "$LOG_FILE" 2>&1 &
PID=$!

# 写入 PID 文件
echo "$PID" > "$PID_FILE"

# 等待 2 秒验证进程是否成功启动
sleep 2
if kill -0 "$PID" 2>/dev/null; then
    echo "ComfyUI 已成功启动 (PID: $PID)"
    echo "日志文件: $LOG_FILE"
    echo "查看日志: tail -f $LOG_FILE"
else
    echo "ComfyUI 启动失败,请查看日志: $LOG_FILE"
    rm -f "$PID_FILE"
    exit 1
fi
