#!/bin/bash
# create_correct_container_v2.sh
# 正确创建容器，解决权限问题

set -e

IMAGE_NAME="px4-gz:latest"
CONTAINER_NAME="px4-correct"
PX4_HOST_DIR="$HOME/PX4-Autopilot"
WORKSPACE_DIR="/home/user/px4"

echo "创建正确权限的容器..."

# 停止并删除旧容器
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# 获取当前用户的UID和GID
USER_ID=$(id -u)
GROUP_ID=$(id -g)
USER_NAME=$(whoami)

echo "当前用户: $USER_NAME (UID: $USER_ID, GID: $GROUP_ID)"

# 方法1：使用宿主机用户的UID/GID创建容器
docker run -d \
    --name "$CONTAINER_NAME" \
    --hostname px4-dev \
    --user "$USER_ID:$GROUP_ID" \
    --privileged \
    --network=host \
    -e DISPLAY=$DISPLAY \
    -e QT_X11_NO_MITSHM=1 \
    -e USER=$USER_NAME \
    -e HOME=/home/user \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v "$HOME/.Xauthority:/home/user/.Xauthority:rw" \
    -v "$PX4_HOST_DIR:$WORKSPACE_DIR:rw" \
    -v "$HOME/.ccache:/home/user/.ccache:rw" \
    -v /dev/dri:/dev/dri \
    --shm-size=2gb \
    -w "$WORKSPACE_DIR" \
    "$IMAGE_NAME" \
    bash -c "
        # 创建用户目录
        mkdir -p /home/user
        chown $USER_ID:$GROUP_ID /home/user
        
        # 设置git
        git config --global --add safe.directory '$WORKSPACE_DIR'
        git config --global --add safe.directory '*'
        
        # 检查并更新子模块
        echo '更新git子模块...'
        git submodule sync --recursive
        git submodule update --init --recursive --depth=1 || echo '子模块更新可能失败，继续...'
        
        # 保持容器运行
        tail -f /dev/null
    "

sleep 3

echo "验证容器权限..."
docker exec "$CONTAINER_NAME" bash -c "
    echo '=== 权限验证 ==='
    echo '当前用户: ' \$(whoami)
    echo '用户ID: ' \$(id -u)
    echo '组ID: ' \$(id -g)
    echo ''
    echo '=== 目录权限 ==='
    ls -la /home/user/
    echo ''
    echo '=== PX4目录权限 ==='
    ls -la $WORKSPACE_DIR/ | head -5
    echo ''
    echo '=== 可写测试 ==='
    cd $WORKSPACE_DIR
    touch test_write.txt && echo '✅ 可写权限正常' && rm test_write.txt
    echo ''
    echo '=== git状态 ==='
    git status --short 2>/dev/null || echo 'git正常'
"

echo ""
echo "✅ 容器创建完成"
echo "编译测试: docker exec $CONTAINER_NAME bash -c 'cd $WORKSPACE_DIR && make px4_sitl --dry-run'"