#!/bin/bash
# create_px4_container.sh
# 创建并运行PX4开发容器

set -e

# 配置
CONTAINER_NAME="px4-dev"
IMAGE_NAME="px4-base:latest"
PX4_HOST_DIR="$HOME/vls_sil/PX4-Autopilot"
WORKSPACE_DIR="/workspace/PX4-Autopilot"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印函数
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_step() { echo -e "${BLUE}➜${NC} $1"; }

# 检查环境
check_environment() {
    print_step "检查环境..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装"
        exit 1
    fi
    print_info "Docker版本: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    
    # 检查镜像
    if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
        print_error "镜像不存在: $IMAGE_NAME"
        echo "请先构建镜像: docker build -t px4-base:latest ."
        exit 1
    fi
    print_info "找到镜像: $IMAGE_NAME"
    
    # 检查PX4代码
    if [ ! -d "$PX4_HOST_DIR" ]; then
        print_warn "PX4代码目录不存在: $PX4_HOST_DIR"
        echo "正在克隆PX4代码..."
        git clone https://github.com/PX4/PX4-Autopilot.git "$PX4_HOST_DIR"
        cd "$PX4_HOST_DIR"
        git submodule sync --recursive
        git submodule update --init --recursive
    else
        print_info "PX4代码目录: $PX4_HOST_DIR"
    fi
    
    # 检查显示
    if [ -z "$DISPLAY" ]; then
        export DISPLAY=:0
        print_warn "DISPLAY设置为: $DISPLAY"
    fi
    print_info "DISPLAY: $DISPLAY"
    
    # 允许Docker访问X11
    xhost +local:docker > /dev/null 2>&1
    print_info "已允许Docker访问X11"
}

# 停止并删除现有容器
clean_existing_container() {
    print_step "清理现有容器..."
    
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        print_info "发现现有容器: $CONTAINER_NAME"
        read -p "是否删除现有容器? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker stop "$CONTAINER_NAME" 2>/dev/null || true
            docker rm "$CONTAINER_NAME" 2>/dev/null || true
            print_info "已删除容器: $CONTAINER_NAME"
        else
            print_info "使用现有容器"
            return 1
        fi
    fi
    return 0
}

# 创建容器
create_container() {
    print_step "创建容器..."
    
    # 创建必要的目录
    mkdir -p "$HOME/.px4_docker"
    mkdir -p "$HOME/.gazebo"
    mkdir -p "$HOME/.ros"
    
    # 运行容器
    print_info "启动容器 (后台模式)..."
    docker run -d \
        --name "$CONTAINER_NAME" \
        --hostname px4-dev \
        --privileged \
        --network=host \
        -e DISPLAY=$DISPLAY \
        -e QT_X11_NO_MITSHM=1 \
        -e TERM=xterm-256color \
        -e NVIDIA_VISIBLE_DEVICES=all \
        -e NVIDIA_DRIVER_CAPABILITIES=all \
        -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
        -v "$HOME/.Xauthority:/home/user/.Xauthority:ro" \
        -v "$PX4_HOST_DIR:$WORKSPACE_DIR:rw" \
        -v "$HOME/.px4_docker:/home/user/.px4:rw" \
        -v "$HOME/.gazebo:/home/user/.gazebo:rw" \
        -v "$HOME/.ros:/home/user/.ros:rw" \
        -v /dev/dri:/dev/dri \
        -v /dev/shm:/dev/shm \
        --shm-size=2gb \
        -w "$WORKSPACE_DIR" \
        "$IMAGE_NAME" \
        tail -f /dev/null
    
    if [ $? -eq 0 ]; then
        print_info "容器创建成功: $CONTAINER_NAME"
    else
        print_error "容器创建失败"
        exit 1
    fi
    
    # 等待容器启动
    sleep 2
    
    # 检查容器状态
    if docker ps | grep -q "$CONTAINER_NAME"; then
        print_info "容器运行状态: 正常"
    else
        print_error "容器未运行"
        docker logs "$CONTAINER_NAME"
        exit 1
    fi
}

# 安装容器内依赖
install_container_deps() {
    print_step "安装容器内依赖..."
    
    # 更新apt
    docker exec "$CONTAINER_NAME" bash -c "
        echo '更新软件包列表...' &&
        sudo apt-get update
    "
    
    # 安装编译依赖
    print_info "安装编译工具..."
    docker exec "$CONTAINER_NAME" bash -c "
        sudo apt-get install -y \
            build-essential \
            cmake \
            ninja-build \
            python3-pip \
            python3-dev \
            git \
            wget \
            curl \
            vim \
            nano
    "

    # 1. 首先添加OSRF仓库
    print_info "添加OSRF仓库..."
    docker exec "$CONTAINER_NAME" bash -c "
        sudo apt-get update &&
        sudo apt-get install -y \
            curl \
            gnupg \
            lsb-release \
            software-properties-common &&
        
        # 添加OSRF密钥
        sudo curl https://packages.osrfoundation.org/gazebo.gpg --output /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg && 
        # 添加仓库
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] https://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null &&
        sudo apt-get update
    "

    # 安装Gazebo依赖
    print_info "安装Gazebo Harmonic 8.9.0..."
    docker exec "$CONTAINER_NAME" bash -c '
        sudo apt-get install -y \
            gz-harmonic
    '
    
    # 清理
    docker exec "$CONTAINER_NAME" bash -c "
        sudo apt-get clean &&
        sudo rm -rf /var/lib/apt/lists/*
    "
    
    print_info "依赖安装完成"
}

# 编译PX4
compile_px4() {
    print_step "编译PX4..."
    
    print_info "进入PX4目录: $WORKSPACE_DIR"
    
    # 编译PX4 SITL
    print_info "开始编译 (这可能需要一些时间)..."
    
    docker exec -it "$CONTAINER_NAME" bash -c "
        cd '$WORKSPACE_DIR' &&
        echo '当前目录: \$(pwd)' &&
        echo '文件列表:' &&
        ls -la &&
        echo '' &&
        echo '开始编译PX4 SITL...' &&
        make px4_sitl
    "
    
    if [ $? -eq 0 ]; then
        print_info "✅ PX4编译成功！"
        
        # 检查生成的文件
        docker exec "$CONTAINER_NAME" bash -c "
            echo '' &&
            echo '编译输出文件:' &&
            ls -la build/px4_sitl_default/bin/ &&
            echo '' &&
            echo '可执行文件大小:' &&
            ls -lh build/px4_sitl_default/bin/px4
        "
    else
        print_error "❌ PX4编译失败"
        exit 1
    fi
}

# 运行Gazebo仿真
run_gazebo_simulation() {
    print_step "运行Gazebo仿真..."
    
    local model=${1:-iris}
    local world=${2:-empty}
    local speedup=${3:-1}
    
    print_info "无人机模型: $model"
    print_info "仿真世界: $world"
    print_info "速度倍数: ${speedup}x"
    
    # 设置环境变量
    docker exec "$CONTAINER_NAME" bash -c "
        export PX4_SIM_MODEL=$model &&
        export PX4_SIM_SPEED_FACTOR=$speedup &&
        export PX4_HOME_LAT=40.7128 &&
        export PX4_HOME_LON=-74.0060 &&
        export PX4_HOME_ALT=0.0 &&
        export GAZEBO_MODEL_PATH=\$GAZEBO_MODEL_PATH:$WORKSPACE_DIR/Tools/simulation/gazebo/sitl_gazebo/models &&
        export GAZEBO_RESOURCE_PATH=\$GAZEBO_RESOURCE_PATH:$WORKSPACE_DIR/Tools/simulation/gazebo/sitl_gazebo/worlds
    "
    
    # 在新终端中启动Gazebo
    print_info "启动Gazebo仿真 (在新终端中)..."
    
    # 方法1: 在容器内直接运行
    docker exec -it "$CONTAINER_NAME" bash -c "
        cd '$WORKSPACE_DIR' &&
        echo '启动PX4 SITL with Gazebo...' &&
        make px4_sitl gazebo-classic_${model}
    "
}

# 显示容器信息
show_container_info() {
    print_step "容器信息"
    echo ""
    echo "══════════════════════════════════════════════════════════"
    echo "容器名称:    $CONTAINER_NAME"
    echo "镜像:       $IMAGE_NAME"
    echo "状态:       $(docker inspect -f '{{.State.Status}}' $CONTAINER_NAME)"
    echo "IP地址:     $(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $CONTAINER_NAME 2>/dev/null || echo 'host network')"
    echo ""
    echo "挂载的目录:"
    echo "  宿主机PX4代码:  $PX4_HOST_DIR"
    echo "  容器内路径:     $WORKSPACE_DIR"
    echo "  Gazebo配置:     $HOME/.gazebo"
    echo "  ROS配置:        $HOME/.ros"
    echo ""
    echo "连接信息:"
    echo "  MAVLink UDP:    127.0.0.1:14550"
    echo "  Gazebo TCP:     127.0.0.1:4560"
    echo "  ROS端口:        11311"
    echo ""
    echo "管理命令:"
    echo "  docker exec -it $CONTAINER_NAME bash     # 进入容器"
    echo "  docker logs -f $CONTAINER_NAME           # 查看日志"
    echo "  docker stop $CONTAINER_NAME             # 停止容器"
    echo "  docker start $CONTAINER_NAME            # 启动容器"
    echo "  docker restart $CONTAINER_NAME          # 重启容器"
    echo "══════════════════════════════════════════════════════════"
}

# 主函数
main() {
    echo "🚀 PX4 Docker容器创建脚本"
    echo "="$(printf '=%.0s' {1..50})
    
    # 检查参数
    if [ "$1" = "--compile-only" ]; then
        COMPILE_ONLY=true
    elif [ "$1" = "--run-only" ]; then
        RUN_ONLY=true
    fi
    
    # 检查环境
    check_environment
    
    if [ "$RUN_ONLY" != true ]; then
        # 清理现有容器
        if clean_existing_container; then
            # 创建新容器
            create_container
            
            # 安装依赖
            install_container_deps
            
            # 编译PX4
            compile_px4
        else
            # 使用现有容器
            print_info "使用现有容器，跳过编译..."
        fi
    fi
    
    if [ "$COMPILE_ONLY" != true ]; then
        # 运行仿真
        if [ -n "$2" ]; then
            run_gazebo_simulation "$2" "${3:-empty}" "${4:-1}"
        else
            print_info "要启动仿真，请运行:"
            echo "  ./create_px4_container.sh --run-only iris"
            echo ""
            echo "或进入容器手动运行:"
            echo "  docker exec -it $CONTAINER_NAME bash"
            echo "  cd /workspace/PX4-Autopilot"
            echo "  make px4_sitl gazebo-classic_iris"
        fi
    fi
    
    # 显示信息
    show_container_info
}

# 捕获Ctrl+C
trap 'echo ""; print_info "脚本被中断"; exit 0' INT

# 运行主函数
main "$@"