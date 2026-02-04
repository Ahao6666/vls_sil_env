#!/bin/bash
# fix_permissions.sh
# 修复容器内的权限问题

set -e

CONTAINER_NAME="px4-dev"
WORKSPACE_DIR="/workspace/PX4-Autopilot"

echo "🔧 修复权限和git安全问题..."

# 修复权限
fix_permissions() {
    echo "修复文件和目录权限..."
    
    docker exec "$CONTAINER_NAME" bash -c "
        echo '当前用户:'
        whoami
        id
        echo ''
        
        echo '修复PX4目录权限...'
        sudo chown -R user:user '$WORKSPACE_DIR'
        
        echo '检查权限...'
        ls -la '$WORKSPACE_DIR' | head -5
    "
}

# 修复git安全目录
fix_git_safe_directory() {
    echo "修复git安全目录..."
    
    docker exec "$CONTAINER_NAME" bash -c "
        echo '添加git安全目录...'
        git config --global --add safe.directory '$WORKSPACE_DIR'
        git config --global --add safe.directory '*'
        
        echo 'git配置:'
        git config --global --list | grep safe
    "
}

# 彻底清理build目录
clean_build_thoroughly() {
    echo "彻底清理build目录..."
    
    docker exec "$CONTAINER_NAME" bash -c "
        cd '$WORKSPACE_DIR'
        
        echo '使用sudo清理build目录...'
        sudo rm -rf build/ || true
        
        echo '使用force清理...'
        rm -rf build/ 2>/dev/null || true
        
        echo '检查是否清理干净...'
        if [ ! -d 'build' ]; then
            echo '✅ build目录已清理'
        else
            echo '⚠️  build目录仍然存在，尝试强制删除...'
            sudo rm -rf build/*
            sudo rm -rf build/
        fi
        
        echo '当前目录:'
        ls -la | grep -E 'build|total'
    "
}

# 重新编译
recompile() {
    echo "重新编译PX4..."
    
    docker exec -it "$CONTAINER_NAME" bash -c "
        set -e
        cd '$WORKSPACE_DIR'
        
        echo '当前目录: \$(pwd)'
        echo ''
        
        echo '检查git状态...'
        git status --short || echo 'git正常'
        echo ''
        
        echo '开始编译...'
        make px4_sitl
        
        echo ''
        if [ -f 'build/px4_sitl_default/bin/px4' ]; then
            echo '✅ 编译成功！'
            ls -lh build/px4_sitl_default/bin/px4
        else
            echo '❌ 编译失败'
            exit 1
        fi
    "
}

# 主函数
main() {
    echo "开始修复权限问题"
    echo "=================="
    
    # 检查容器
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        echo "错误: 容器未运行: $CONTAINER_NAME"
        exit 1
    fi
    
    fix_permissions
    fix_git_safe_directory
    clean_build_thoroughly
    recompile
    
    echo ""
    echo "✅ 修复完成！"
}

main "$@"