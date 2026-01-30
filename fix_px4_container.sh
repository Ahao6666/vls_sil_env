#!/bin/bash
# fix_px4_container.sh
# 修复容器内的PX4编译问题

set -e

CONTAINER_NAME="px4-dev"
WORKSPACE_DIR="/workspace/PX4-Autopilot"

echo "🔧 修复PX4编译环境..."

# 清理容器内的旧编译缓存
clean_build_cache() {
    echo "清理编译缓存..."
    
    docker exec "$CONTAINER_NAME" bash -c "
        cd '$WORKSPACE_DIR'
        
        echo '当前工作目录:'
        pwd
        echo ''
        
        echo '清理旧的build目录...'
        if [ -d 'build' ]; then
            rm -rf build/
            echo '✅ 已删除build目录'
        else
            echo '⚠️  build目录不存在'
        fi
        
        echo ''
        echo '清理ninja缓存...'
        if [ -d '.ninja_deps' ]; then
            rm -rf .ninja_deps .ninja_log
            echo '✅ 已清理ninja缓存'
        fi
        
        echo ''
        echo '当前目录内容:'
        ls -la
    "
}

# 重新初始化仓库
reinit_repository() {
    echo "重新初始化仓库..."
    
    docker exec "$CONTAINER_NAME" bash -c "
        cd '$WORKSPACE_DIR'
        
        echo '更新子模块...'
        git submodule sync --recursive
        git submodule update --init --recursive
        
        echo ''
        echo '子模块状态:'
        git submodule status
    "
}

# 验证环境
verify_environment() {
    echo "验证容器环境..."
    
    docker exec "$CONTAINER_NAME" bash -c "
        echo '=== 容器信息 ==='
        echo '主机名: ' \$(hostname)
        echo '用户: ' \$(whoami)
        echo '工作目录: ' \$(pwd)
        echo ''
        
        echo '=== PX4目录 ==='
        cd '$WORKSPACE_DIR'
        echo '实际路径: ' \$(pwd -P)
        echo '符号链接: ' \$(readlink -f .)
        echo '目录内容:'
        ls -la
        echo ''
        
        echo '=== 工具版本 ==='
        cmake --version | head -1
        make --version | head -1
        gcc --version | head -1
        python3 --version
    "
}

# 重新编译PX4
recompile_px4() {
    local target=${1:-px4_sitl}
    
    echo "重新编译PX4 ($target)..."
    
    docker exec -it "$CONTAINER_NAME" bash -c "
        set -e
        cd '$WORKSPACE_DIR'
        
        echo '当前目录: \$(pwd)'
        echo '绝对路径: \$(pwd -P)'
        echo ''
        
        # 确保是干净的
        echo '确保干净的构建环境...'
        if [ -d 'build' ]; then
            echo '发现旧的build目录，删除...'
            rm -rf build/
        fi
        
        # 创建build目录
        mkdir -p build
        
        echo ''
        echo '开始编译...'
        echo '编译目标: $target'
        echo ''
        
        # 使用详细模式编译
        make $target VERBOSE=1
        
        echo ''
        if [ -f 'build/px4_sitl_default/bin/px4' ]; then
            echo '✅ 编译成功！'
            echo '可执行文件位置: build/px4_sitl_default/bin/px4'
            ls -lh build/px4_sitl_default/bin/px4
        else
            echo '❌ 编译失败'
            exit 1
        fi
    "
}

# 测试编译
test_compile() {
    echo "测试编译..."
    
    docker exec "$CONTAINER_NAME" bash -c "
        cd '$WORKSPACE_DIR'
        
        echo '=== 测试CMake ==='
        mkdir -p build/test
        cd build/test
        
        # 运行CMake但不编译
        cmake ../.. -GNinja
        
        echo ''
        echo 'CMake缓存内容:'
        grep -i 'project\|source\|binary' CMakeCache.txt || true
    "
}

# 主函数
main() {
    echo "开始修复PX4容器环境"
    echo "====================="
    
    # 检查容器
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        echo "错误: 容器未运行: $CONTAINER_NAME"
        exit 1
    fi
    
    # 执行修复步骤
    verify_environment
    clean_build_cache
    reinit_repository
    test_compile
    recompile_px4
    
    echo ""
    echo "✅ 修复完成！"
}

main "$@"