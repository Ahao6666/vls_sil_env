#!/bin/bash
# entrypoint.sh

set -e

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查显示设置
if [ -z "$DISPLAY" ]; then
    log_warn "DISPLAY未设置，尝试设置默认值"
    export DISPLAY=:0
fi

# 启动Xvfb虚拟显示（如果DISPLAY是:99）
if [[ "$DISPLAY" == ":99" ]]; then
    log_info "启动Xvfb虚拟显示"
    Xvfb :99 -screen 0 1920x1080x24+32 &
fi

# 初始化ROS2环境
if [ -n "${ROS_DISTRO}" ]; then
    log_info "初始化ROS2环境: ${ROS_DISTRO}"
    source "/opt/ros/$ROS_DISTRO/setup.bash"
    
    # 设置ROS网络
    if [ -z "$ROS_DOMAIN_ID" ]; then
        export ROS_DOMAIN_ID=0
    fi
    if [ -z "$ROS_LOCALHOST_ONLY" ]; then
        export ROS_LOCALHOST_ONLY=0
    fi
fi

# 设置Gazebo环境
if [ -n "${GZ_VERSION}" ]; then
    log_info "Gazebo版本: ${GZ_VERSION}"
    export GZ_SIM_RESOURCE_PATH=/workspace/PX4-Autopilot/Tools/simulation/gz
fi

# 设置MAVLink
if [ -z "$PX4_SIM_MODEL" ]; then
    export PX4_SIM_MODEL=iris
fi
if [ -z "$PX4_HOME_LAT" ]; then
    export PX4_HOME_LAT=40.7128
fi
if [ -z "$PX4_HOME_LON" ]; then
    export PX4_HOME_LON=-74.0060
fi
if [ -z "$PX4_HOME_ALT" ]; then
    export PX4_HOME_ALT=0.0
fi

# 检查PX4代码目录
if [ -d "/workspace/PX4-Autopilot" ]; then
    log_info "PX4代码目录存在: /workspace/PX4-Autopilot"
    export PX4_DIR=/workspace/PX4-Autopilot
    cd $PX4_DIR
    
    # 设置环境变量
    export GAZEBO_MODEL_PATH=${PX4_DIR}/Tools/simulation/gz/models:${GAZEBO_MODEL_PATH}
    export GAZEBO_RESOURCE_PATH=${PX4_DIR}/Tools/simulation/gz/worlds:${GAZEBO_RESOURCE_PATH}
    
    # 检查是否需要重新编译
    if [ ! -f "${PX4_DIR}/build/px4_sitl_default/bin/px4" ]; then
        log_warn "PX4未编译，开始编译..."
        make px4_sitl || {
            log_error "PX4编译失败"
            exit 1
        }
    fi
    
    # 添加编译目录到PATH
    export PATH=${PX4_DIR}/build/px4_sitl_default:${PATH}
else
    log_warn "PX4代码目录不存在，请挂载宿主机的PX4-Autopilot目录到/workspace/PX4-Autopilot"
fi

# 启动roscore（如果ROS_MASTER_URI未设置）
if [ -z "$ROS_MASTER_URI" ]; then
    log_info "启动roscore..."
    roscore &
    sleep 2
fi

log_info "环境初始化完成"
log_info "PX4模型: ${PX4_SIM_MODEL}"
log_info "ROS Domain ID: ${ROS_DOMAIN_ID}"
log_info "Gazebo版本: ${GZ_VERSION}"
log_info "工作目录: $(pwd)"

# 执行传入的命令
exec "$@"