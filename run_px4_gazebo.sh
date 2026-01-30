#!/bin/bash
# run_px4_gazebo.sh
# 在Docker容器中运行PX4 SITL with Gazebo

set -e  # 遇到错误时退出

# 配置参数
CONTAINER_NAME="px4-sitl-ros2"
IMAGE_NAME="px4-base:latest"
PX4_HOST_DIR="$HOME/vls_sil/PX4-Autopilot"  # 宿主机上的PX4代码路径
WORKSPACE_DIR="/workspace/PX4-Autopilot"  # 容器内的PX4代码路径
SHARED_MEMORY="2gb"  # 共享内存大小
MODEL="iris"  # 默认无人机模型
WORLD="empty"  # 默认Gazebo世界
SPEEDUP="1"  # 仿真速度
MAVLINK_UDP_PORT=14550
GAZEBO_TCP_PORT=4560
ROS_MASTER_PORT=11311
JUPYTER_PORT=8888

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}➜${NC} $1"
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help            显示此帮助信息"
    echo "  -m, --model MODEL     设置无人机模型 (默认: iris)"
    echo "                         可用: iris, typhoon_h480, standard_vtol, tailsitter, plane, rover"
    echo "  -w, --world WORLD     设置Gazebo世界 (默认: empty)"
    echo "                         可用: empty, baylands, mcmillan_airfield, sonoma_raceway, warehouse"
    echo "  -s, --speedup SPEED   设置仿真速度倍数 (默认: 1)"
    echo "  -d, --detach          后台运行容器"
    echo "  -b, --build           重新编译PX4"
    echo "  -c, --clean           清理旧的容器和镜像"
    echo "  -t, --test            测试环境"
    echo "  -l, --logs            查看容器日志"
    echo "  -a, --attach          附加到运行中的容器"
    echo "  -r, --ros            启动ROS2节点"
    echo ""
    echo "示例:"
    echo "  $0                       # 使用默认设置启动"
    echo "  $0 -m typhoon_h480      # 启动Typhoon H480"
    echo "  $0 -w warehouse         # 在仓库世界中启动"
    echo "  $0 -s 2 -b              # 2倍速度并重新编译"
    echo "  $0 -c                   # 清理环境"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -w|--world)
            WORLD="$2"
            shift 2
            ;;
        -s|--speedup)
            SPEEDUP="$2"
            shift 2
            ;;
        -d|--detach)
            DETACH=true
            shift
            ;;
        -b|--build)
            REBUILD=true
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -t|--test)
            TEST_ONLY=true
            shift
            ;;
        -l|--logs)
            SHOW_LOGS=true
            shift
            ;;
        -a|--attach)
            ATTACH=true
            shift
            ;;
        -r|--ros)
            START_ROS=true
            shift
            ;;
        *)
            print_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 清理函数
clean_environment() {
    print_step "清理环境..."
    
    # 停止并删除容器
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
        print_info "已删除容器: $CONTAINER_NAME"
    fi
    
    # 清理Docker资源
    docker system prune -f
    
    # 清理临时文件
    rm -rf /tmp/px4-* /tmp/gazebo-*
    
    print_info "环境清理完成"
    exit 0
}

# 测试函数
test_environment() {
    print_step "测试环境..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装"
        exit 1
    fi
    print_info "✓ Docker已安装"
    
    # 检查Docker镜像
    if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
        print_error "镜像不存在: $IMAGE_NAME"
        print_info "请先运行: docker build -t px4-base:latest ."
        exit 1
    fi
    print_info "✓ Docker镜像存在: $IMAGE_NAME"
    
    # 检查PX4代码
    if [ ! -d "$PX4_HOST_DIR" ]; then
        print_error "PX4代码目录不存在: $PX4_HOST_DIR"
        print_info "请先运行: git clone https://github.com/PX4/PX4-Autopilot.git $PX4_HOST_DIR"
        exit 1
    fi
    print_info "✓ PX4代码目录存在"
    
    # 检查显示
    if [ -z "$DISPLAY" ]; then
        DISPLAY=":0"
        export DISPLAY
        print_warn "DISPLAY未设置，使用: $DISPLAY"
    fi
    print_info "✓ DISPLAY: $DISPLAY"
    
    # 允许Docker访问X11
    xhost +local:docker > /dev/null 2>&1
    print_info "✓ X11权限已设置"
    
    print_info "环境测试通过！"
    
    if [ "$TEST_ONLY" = true ]; then
        exit 0
    fi
}

# 查看日志
show_logs() {
    if docker ps | grep -q "$CONTAINER_NAME"; then
        docker logs -f "$CONTAINER_NAME"
    else
        print_error "容器未运行: $CONTAINER_NAME"
    fi
    exit 0
}

# 附加到容器
attach_container() {
    if docker ps | grep -q "$CONTAINER_NAME"; then
        print_info "附加到容器: $CONTAINER_NAME"
        docker exec -it "$CONTAINER_NAME" bash
    else
        print_error "容器未运行: $CONTAINER_NAME"
    fi
    exit 0
}

# 主运行函数
run_simulation() {
    print_step "启动PX4 SITL仿真..."
    
    # 检查容器是否已运行
    if docker ps | grep -q "$CONTAINER_NAME"; then
        print_warn "容器已在运行: $CONTAINER_NAME"
        read -p "是否重启? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker stop "$CONTAINER_NAME"
            docker rm "$CONTAINER_NAME"
        else
            print_info "附加到现有容器..."
            docker exec -it "$CONTAINER_NAME" bash
            exit 0
        fi
    fi
    
    # 设置环境变量
    export GAZEBO_MODEL_PATH="${PX4_HOST_DIR}/Tools/simulation/gazebo/sitl_gazebo/models:$GAZEBO_MODEL_PATH"
    export GAZEBO_RESOURCE_PATH="${PX4_HOST_DIR}/Tools/simulation/gazebo/sitl_gazebo/worlds:$GAZEBO_RESOURCE_PATH"
    
    # 创建日志目录
    LOG_DIR="$HOME/px4_logs/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$LOG_DIR"
    
    # Docker运行命令
    DOCKER_CMD="docker run"
    
    if [ "$DETACH" = true ]; then
        DOCKER_CMD="$DOCKER_CMD -d"
    else
        DOCKER_CMD="$DOCKER_CMD -it"
    fi
    
    DOCKER_CMD="$DOCKER_CMD --name $CONTAINER_NAME"
    DOCKER_CMD="$DOCKER_CMD --hostname px4-sitl"
    DOCKER_CMD="$DOCKER_CMD --shm-size=$SHARED_MEMORY"
    DOCKER_CMD="$DOCKER_CMD --privileged"
    DOCKER_CMD="$DOCKER_CMD --rm"
    DOCKER_CMD="$DOCKER_CMD --network=host"
    DOCKER_CMD="$DOCKER_CMD -e DISPLAY=$DISPLAY"
    DOCKER_CMD="$DOCKER_CMD -e QT_X11_NO_MITSHM=1"
    DOCKER_CMD="$DOCKER_CMD -e PX4_SIM_MODEL=$MODEL"
    DOCKER_CMD="$DOCKER_CMD -e PX4_SIM_SPEED_FACTOR=$SPEEDUP"
    DOCKER_CMD="$DOCKER_CMD -e PX4_HOME_LAT=40.7128"
    DOCKER_CMD="$DOCKER_CMD -e PX4_HOME_LON=-74.0060"
    DOCKER_CMD="$DOCKER_CMD -e PX4_HOME_ALT=0.0"
    DOCKER_CMD="$DOCKER_CMD -v /tmp/.X11-unix:/tmp/.X11-unix:rw"
    DOCKER_CMD="$DOCKER_CMD -v $HOME/.Xauthority:/home/user/.Xauthority:ro"
    DOCKER_CMD="$DOCKER_CMD -v $PX4_HOST_DIR:$WORKSPACE_DIR:rw"
    DOCKER_CMD="$DOCKER_CMD -v $LOG_DIR:/workspace/logs:rw"
    DOCKER_CMD="$DOCKER_CMD -v $HOME/.gazebo:/home/user/.gazebo:rw"
    DOCKER_CMD="$DOCKER_CMD -v /dev/dri:/dev/dri"  # GPU加速
    DOCKER_CMD="$DOCKER_CMD $IMAGE_NAME"
    
    # 运行命令
    print_step "执行命令:"
    echo "$DOCKER_CMD"
    echo ""
    
    eval $DOCKER_CMD
    
    if [ $? -eq 0 ]; then
        print_info "容器启动成功！"
    else
        print_error "容器启动失败"
        exit 1
    fi
}

# 构建函数
build_px4() {
    print_step "在容器中编译PX4..."
    
    if docker ps | grep -q "$CONTAINER_NAME"; then
        print_info "在运行中的容器中编译..."
        docker exec -it "$CONTAINER_NAME" bash -c "
            cd $WORKSPACE_DIR &&
            make clean &&
            make px4_sitl gazebo-classic
        "
    else
        print_info "启动临时容器进行编译..."
        docker run --rm \
            -v "$PX4_HOST_DIR:$WORKSPACE_DIR" \
            -v "$HOME/.ccache:/home/user/.ccache" \
            $IMAGE_NAME \
            bash -c "
                cd $WORKSPACE_DIR &&
                make clean &&
                make px4_sitl gazebo-classic
            "
    fi
    
    if [ $? -eq 0 ]; then
        print_info "PX4编译成功！"
    else
        print_error "PX4编译失败"
        exit 1
    fi
}

# 启动ROS2
start_ros2() {
    print_step "启动ROS2节点..."
    
    if docker ps | grep -q "$CONTAINER_NAME"; then
        docker exec -d "$CONTAINER_NAME" bash -c "
            source /opt/ros/humble/setup.bash &&
            ros2 launch px4_ros_com sensor_combined_listener.launch.py
        "
        print_info "ROS2节点已启动"
    else
        print_error "容器未运行，无法启动ROS2"
    fi
}

# 显示状态
show_status() {
    print_step "仿真状态"
    echo ""
    echo "══════════════════════════════════════════════════════════"
    echo "容器状态: $(docker ps | grep -q "$CONTAINER_NAME" && echo "运行中" || echo "停止")"
    echo "无人机模型: $MODEL"
    echo "Gazebo世界: $WORLD"
    echo "仿真速度: ${SPEEDUP}x"
    echo "日志目录: $LOG_DIR"
    echo ""
    echo "连接信息:"
    echo "  MAVLink UDP:    127.0.0.1:$MAVLINK_UDP_PORT"
    echo "  Gazebo TCP:     127.0.0.1:$GAZEBO_TCP_PORT"
    echo "  ROS Master:     http://127.0.0.1:$ROS_MASTER_PORT"
    echo "  Jupyter:        http://127.0.0.1:$JUPYTER_PORT (如启用)"
    echo ""
    echo "常用命令:"
    echo "  docker exec -it $CONTAINER_NAME bash    # 进入容器"
    echo "  docker logs -f $CONTAINER_NAME          # 查看日志"
    echo "  docker stop $CONTAINER_NAME            # 停止容器"
    echo "══════════════════════════════════════════════════════════"
}

# 主执行流程
main() {
    # 根据参数执行不同操作
    if [ "$CLEAN" = true ]; then
        clean_environment
    fi
    
    if [ "$SHOW_LOGS" = true ]; then
        show_logs
    fi
    
    if [ "$ATTACH" = true ]; then
        attach_container
    fi
    
    # 测试环境
    test_environment
    
    # 清理可能存在的旧容器
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    fi
    
    # 如果需要重新编译
    if [ "$REBUILD" = true ]; then
        build_px4
    fi
    
    运行仿真
    run_simulation
    
    # 如果需要启动ROS2
    # if [ "$START_ROS" = true ]; then
    #     sleep 5  # 等待PX4启动
    #     start_ros2
    # fi
    
    # 如果不是后台运行，显示状态
    if [ "$DETACH" != true ]; then
        show_status
        
        # 如果不是交互模式，等待用户退出
        if [ -t 0 ]; then
            echo ""
            read -p "按回车键停止仿真..." -r
            docker stop "$CONTAINER_NAME"
        fi
    else
        show_status
    fi
}

# 捕获Ctrl+C
trap 'print_info "正在停止容器..."; docker stop "$CONTAINER_NAME" 2>/dev/null || true; exit 0' INT

# 运行主函数
main
