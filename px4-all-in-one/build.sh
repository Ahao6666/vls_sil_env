#!/bin/bash
# build.sh - 构建一体化PX4仿真镜像

set -e

# 配置
# IMAGE_NAME="px4-pip"
IMAGE_NAME="px4-all-in-one"
IMAGE_TAG="latest"
DOCKERFILE="Dockerfile.px4-all-in-one"
# DOCKERFILE="Dockerfile.pip"
BUILD_CONTEXT="."

echo "🔨 构建一体化PX4仿真镜像..."
echo "镜像名称: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "Dockerfile: ${DOCKERFILE}"

# 检查必需文件
if [ ! -f "${DOCKERFILE}" ]; then
    echo "错误: Dockerfile不存在: ${DOCKERFILE}"
    exit 1
fi

if [ ! -f "entrypoint.sh" ]; then
    echo "错误: entrypoint.sh不存在"
    exit 1
fi

# 设置构建参数（使用当前用户的UID/GID）
USER_ID=$(id -u)
GROUP_ID=$(id -g)
USERNAME=$(whoami)

echo "构建参数:"
echo "  USER_ID: ${USER_ID}"
echo "  GROUP_ID: ${GROUP_ID}"
echo "  USERNAME: ${USERNAME}"

# 构建镜像
docker build \
    -f "${DOCKERFILE}" \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    --build-arg USER_ID=${USER_ID} \
    --build-arg GROUP_ID=${GROUP_ID} \
    --build-arg USERNAME=${USERNAME} \
    --build-arg http_proxy=${http_proxy} \
    --build-arg https_proxy=${https_proxy} \
    --build-arg no_proxy=${no_proxy} \
    --progress=plain \
    "${BUILD_CONTEXT}"

# 验证构建结果
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 镜像构建成功！"
    echo ""
    echo "可用镜像:"
    docker images | grep "${IMAGE_NAME}"
    
    # 测试镜像
    echo ""
    echo "🧪 测试镜像..."
    docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" bash -c "
        echo '=== 环境测试 ==='
        echo 'ROS版本:' && ros2 --version
        echo ''
        echo 'Gazebo版本:' && gz --versions
        echo ''
        echo 'MAVROS包:' && ros2 pkg list | grep mavros
        echo ''
        echo 'Python包:'
        python3 -c \"import pymavlink; print(f'pymavlink: OK ({pymavlink.__version__})')\"
    "
    
    # 保存镜像
    echo ""
    echo "💾 保存镜像..."
    docker save "${IMAGE_NAME}:${IMAGE_TAG}" -o "${IMAGE_NAME}.tar"
    echo "镜像已保存到: ${IMAGE_NAME}.tar"
    
else
    echo "❌ 镜像构建失败"
    exit 1
fi