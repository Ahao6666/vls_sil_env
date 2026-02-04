#!/bin/bash
# run_px4_container.sh
# 使用px4-gz镜像创建并运行容器

set -e

# 配置
IMAGE_NAME="px4-gz:latest"
CONTAINER_NAME="px4-gz:latest"
PX4_HOST_DIR="$HOME/vls_sil/PX4-Autopilot"
WORKSPACE_DIR="/workspace/PX4-Autopilot"

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
        echo_info "请先构建镜像: docker build -t px4-gz:latest -f Dockerfile.px4-gz ."
        exit 1
    fi
    
    # 检查PX4代码
    if [ ! -d "$PX4_HOST_DIR" ]; then
        echo_error "PX4代码目录不存在: $PX4_HOST_DIR"
        echo_info "请先克隆代码: git clone https://github.com/PX4/PX4-Autopilot.git $PX4_HOST_DIR"
        exit 1
    fi
    
    # 检查显示
    if [ -z "$DISPLAY" ]; then
        export DISPLAY=:0
    fi
    
    # 允许Docker访问X11
    xhost +local:docker > /dev/null 2>&1
}

# 创建并运行容器
create_container() {
    echo_info "创建并运行容器..."
    
    # 停止并删除现有容器
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    
    # 运行容器
    docker run -d \
        --name "$CONTAINER_NAME" \
        --hostname px4-dev \
        --privileged \
        --network=host \
        -e DISPLAY=$DISPLAY \
        -e QT_X11_NO_MITSHM=1 \
        -e NVIDIA_VISIBLE_DEVICES=all \
        -e NVIDIA_DRIVER_CAPABILITIES=all \
        -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
        -v "$HOME/.Xauthority:/home/user/.Xauthority:ro" \
        -v "$PX4_HOST_DIR:$WORKSPACE_DIR:rw" \
        -v "$HOME/.ccache:/home/user/.ccache:rw" \
        -v "$HOME/.gz:/home/user/.gz:rw" \
        -v "$HOME/.ros:/home/user/.ros:rw" \
        -v /dev/dri:/dev/dri \
        -v /dev/shm:/dev/shm \
        --shm-size=2gb \
        -w "$WORKSPACE_DIR" \
        "$IMAGE_NAME" \
        tail -f /dev/null
    
    # 等待容器启动
    sleep 3
    
    # 验证容器运行
    if docker ps | grep -q "$CONTAINER_NAME"; then
        echo_info "容器创建成功: $CONTAINER_NAME"
    else
        echo_error "容器创建失败"
        exit 1
    fi
}

# 在容器内编译PX4
compile_px4_in_container() {
    local target=${1:-px4_sitl}
    
    echo_info "在容器内编译PX4 ($target)..."
    
    docker exec -it "$CONTAINER_NAME" bash -c "
        set -e
        cd '$WORKSPACE_DIR'
        
        echo '当前目录: \$(pwd)'
        echo '文件列表:'
        ls -la
        echo ''
        
        echo '开始编译...'
        make $target
        
        echo ''
        if [ -f 'build/px4_sitl_default/bin/px4' ]; then
            echo '✅ 编译成功！'
            echo '可执行文件: build/px4_sitl_default/bin/px4'
            ls -lh build/px4_sitl_default/bin/px4
        else
            echo '❌ 编译失败'
            exit 1
        fi
    "
}

# 运行Gazebo仿真
run_gazebo_simulation() {
    local model=${1:-x500}
    
    echo_info "运行Gazebo仿真 ($model)..."
    
    docker exec -it "$CONTAINER_NAME" bash -c "
        source /opt/ros/humble/setup.bash
        
        cd '$WORKSPACE_DIR'
        
        echo '设置环境变量...'
        export PX4_SYS_AUTOSTART=4001
        export PX4_GZ_MODEL=$model
        export PX4_GZ_WORLD=empty
        export GZ_VERSION=harmonic
        
        echo '启动PX4 with Gazebo Harmonic...'
        echo '模型: $model'
        
        # 编译并运行
        make px4_sitl gz_${model}
    "
}

# 进入容器
enter_container() {
    echo_info "进入容器..."
    docker exec -it "$CONTAINER_NAME" bash
}

# 显示帮助
show_help() {
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  create          创建并运行容器"
    echo "  compile [目标]  编译PX4 (默认: px4_sitl)"
    echo "  run [模型]      运行Gazebo仿真 (默认: x500)"
    echo "  bash            进入容器"
    echo "  logs            查看容器日志"
    echo "  stop            停止容器"
    echo "  clean           清理容器"
    echo "  help            显示帮助"
    echo ""
    echo "示例:"
    echo "  $0 create        # 创建容器"
    echo "  $0 compile       # 编译PX4"
    echo "  $0 run x500      # 运行X500仿真"
    echo "  $0 run iris      # 运行Iris仿真"
    echo "  $0 bash          # 进入容器"
}

# 主函数
main() {
    case "$1" in
        create)
            check_dependencies
            create_container
            ;;
        
        compile)
            check_dependencies
            compile_px4_in_container "${2:-px4_sitl}"
            ;;
        
        run)
            check_dependencies
            run_gazebo_simulation "${2:-x500}"
            ;;
        
        bash)
            enter_container
            ;;
        
        logs)
            docker logs -f "$CONTAINER_NAME"
            ;;
        
        stop)
            docker stop "$CONTAINER_NAME"
            echo_info "容器已停止"
            ;;
        
        clean)
            docker stop "$CONTAINER_NAME" 2>/dev/null || true
            docker rm "$CONTAINER_NAME" 2>/dev/null || true
            echo_info "容器已清理"
            ;;
        
        help|*)
            show_help
            ;;
    esac
}

main "$@"