#!/bin/bash
# run.sh - 运行一体化PX4仿真

set -e

# 配置
CONTAINER_NAME="px4-sim"
IMAGE_NAME="px4-all-in-one:latest"
PX4_HOST_DIR="${HOME}/PX4-Autopilot"
WORKSPACE_DIR="/workspace"
SHARED_MEMORY="2gb"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查依赖
check_dependencies() {
    echo_info "检查依赖..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        echo_error "Docker未安装"
        exit 1
    fi
    
    # 检查镜像
    if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
        echo_error "镜像不存在: $IMAGE_NAME"
        echo_info "请先运行: ./build.sh"
        exit 1
    fi
    
    # 检查PX4代码
    if [ ! -d "$PX4_HOST_DIR" ]; then
        echo_error "PX4代码目录不存在: $PX4_HOST_DIR"
        echo_info "请先克隆: git clone https://github.com/PX4/PX4-Autopilot.git $PX4_HOST_DIR"
        exit 1
    fi
    
    # 检查显示
    if [ -z "$DISPLAY" ]; then
        export DISPLAY=:0
        echo_info "设置DISPLAY: $DISPLAY"
    fi
    
    # 允许Docker访问X11
    xhost +local:docker > /dev/null 2>&1
}

# 清理旧容器
cleanup() {
    echo_info "清理旧容器..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
}

# 运行容器
run_container() {
    local model=${1:-iris}
    local world=${2:-empty}
    
    echo_info "运行容器..."
    echo_info "无人机模型: $model"
    echo_info "仿真世界: $world"
    
    # 创建日志目录
    LOG_DIR="${HOME}/px4_logs/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$LOG_DIR"
    
    # 运行容器
    docker run -d \
        --name "$CONTAINER_NAME" \
        --hostname px4-sim \
        --privileged \
        --network=host \
        -e DISPLAY=$DISPLAY \
        -e QT_X11_NO_MITSHM=1 \
        -e NVIDIA_VISIBLE_DEVICES=all \
        -e NVIDIA_DRIVER_CAPABILITIES=all \
        -e PX4_SIM_MODEL=$model \
        -e PX4_GZ_WORLD=$world \
        -e PX4_SIM_SPEED_FACTOR=1 \
        -e ROS_DOMAIN_ID=0 \
        -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
        -v "$HOME/.Xauthority:/home/simuser/.Xauthority:ro" \
        -v "$PX4_HOST_DIR:$WORKSPACE_DIR/PX4-Autopilot:rw" \
        -v "$HOME/.ccache:/home/simuser/.ccache:rw" \
        -v "$HOME/.gazebo:/home/simuser/.gazebo:rw" \
        -v "$HOME/.ros:/home/simuser/.ros:rw" \
        -v "$LOG_DIR:$WORKSPACE_DIR/logs:rw" \
        -v /dev/dri:/dev/dri \
        -v /dev/shm:/dev/shm \
        --shm-size="$SHARED_MEMORY" \
        -w "$WORKSPACE_DIR/PX4-Autopilot" \
        "$IMAGE_NAME" \
        bash -c "
            # 编译PX4（如果需要）
            if [ ! -f 'build/px4_sitl_default/bin/px4' ]; then
                echo '编译PX4...'
                make px4_sitl
            fi
            
            # 启动仿真
            echo '启动仿真...'
            make px4_sitl gz_$model
        "
    
    # 等待容器启动
    sleep 3
    
    # 检查容器状态
    if docker ps | grep -q "$CONTAINER_NAME"; then
        echo_info "✅ 容器启动成功"
    else
        echo_error "❌ 容器启动失败"
        docker logs "$CONTAINER_NAME"
        exit 1
    fi
}

# 显示状态
show_status() {
    echo ""
    echo "========================================"
    echo "         PX4仿真环境已启动"
    echo "========================================"
    echo ""
    echo "容器名称: $CONTAINER_NAME"
    echo "容器状态: $(docker inspect -f '{{.State.Status}}' $CONTAINER_NAME)"
    echo ""
    echo "连接信息:"
    echo "  MAVLink UDP:  127.0.0.1:14550"
    echo "  ROS Master:   http://127.0.0.1:11311"
    echo "  Gazebo GUI:   应该已自动打开"
    echo ""
    echo "管理命令:"
    echo "  查看日志:  docker logs -f $CONTAINER_NAME"
    echo "  进入容器:  docker exec -it $CONTAINER_NAME bash"
    echo "  停止仿真:  docker stop $CONTAINER_NAME"
    echo ""
    echo "在容器内运行:"
    echo "  make px4_sitl                    # 编译PX4"
    echo "  make px4_sitl gz_iris           # 启动Iris仿真"
    echo "  ros2 topic list                 # 查看ROS2话题"
    echo "  gz topic -l                     # 查看Gazebo话题"
    echo "========================================"
}

# 主函数
main() {
    echo "🚀 启动一体化PX4仿真环境"
    echo "========================"
    
    # 解析参数
    MODEL=${1:-iris}
    WORLD=${2:-empty}
    
    check_dependencies
    cleanup
    run_container "$MODEL" "$WORLD"
    show_status
}

# 捕获Ctrl+C
trap 'echo ""; echo_info "正在停止容器..."; docker stop "$CONTAINER_NAME" 2>/dev/null || true; exit 0' INT

main "$@"