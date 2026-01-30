#!/bin/bash
# verify_env.sh
# 验证环境

echo "🔍 验证PX4 Docker环境..."

# 检查Docker
echo "1. 检查Docker..."
if command -v docker &> /dev/null; then
    echo "   ✅ Docker已安装: $(docker --version)"
else
    echo "   ❌ Docker未安装"
    exit 1
fi

# 检查镜像
echo "2. 检查Docker镜像..."
if docker image inspect px4-base:latest &> /dev/null; then
    echo "   ✅ px4-base镜像存在"
else
    echo "   ❌ px4-base镜像不存在"
    echo "   运行: docker build -t px4-base:latest ."
    exit 1
fi

# 检查PX4代码
echo "3. 检查PX4代码..."
if [ -d "$HOME/vls_sil/PX4-Autopilot" ]; then
    echo "   ✅ PX4代码目录存在"
    
    # 检查必要的子模块
    REQUIRED_DIRS=("Tools/simulation/gz" "src" "boards")
    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ -d "$HOME/vls_sil/PX4-Autopilot/$dir" ]; then
            echo "   ✅ $dir 存在"
        else
            echo "   ❌ 缺少: $dir"
            echo "   运行: git submodule update --init --recursive"
        fi
    done
else
    echo "   ❌ PX4代码目录不存在"
    echo "   运行: git clone https://github.com/PX4/PX4-Autopilot.git $HOME/vls_sil/PX4-Autopilot"
    exit 1
fi

# 检查X11
echo "4. 检查显示..."
if [ -z "$DISPLAY" ]; then
    echo "   ⚠️ DISPLAY未设置，尝试设置为:0"
    export DISPLAY=:0
fi
if xhost > /dev/null 2>&1; then
    echo "   ✅ X11服务器可用"
else
    echo "   ⚠️ X11服务器可能有问题"
fi

# 测试Docker运行
echo "5. 测试Docker运行..."
docker run --rm px4-base:latest bash -c "echo '✅ Docker容器测试通过' && gcc --version | head -1"

echo ""
echo "🎉 环境验证完成！"
echo ""
echo "现在可以运行:"
echo "  ./run_px4_gazebo.sh      # 启动仿真"
echo "  ./manage_px4.sh help    # 查看管理命令"