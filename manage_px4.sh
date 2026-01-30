#!/bin/bash
# manage_px4.sh
# PX4仿真管理脚本

case "$1" in
    start)
        shift
        ./run_px4_gazebo.sh "$@"
        ;;
    
    stop)
        CONTAINER_NAME=${2:-px4-sitl-ros2}
        docker stop "$CONTAINER_NAME" 2>/dev/null && echo "已停止容器: $CONTAINER_NAME" || echo "容器未运行: $CONTAINER_NAME"
        ;;
    
    restart)
        ./manage_px4.sh stop
        sleep 2
        ./manage_px4.sh start "${@:2}"
        ;;
    
    build)
        shift
        ./build_px4.sh "$@"
        ;;
    
    logs)
        CONTAINER_NAME=${2:-px4-sitl-ros2}
        docker logs -f "$CONTAINER_NAME"
        ;;
    
    bash)
        CONTAINER_NAME=${2:-px4-sitl-ros2}
        if docker ps | grep -q "$CONTAINER_NAME"; then
            docker exec -it "$CONTAINER_NAME" bash
        else
            echo "容器未运行: $CONTAINER_NAME"
        fi
        ;;
    
    list)
        echo "运行中的PX4容器:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep px4
        echo ""
        echo "所有PX4容器:"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep px4
        ;;
    
    clean)
        echo "清理未使用的Docker资源..."
        docker system prune -f
        
        echo "清理临时文件..."
        rm -rf /tmp/px4-* /tmp/gazebo-*
        
        echo "清理编译缓存..."
        rm -rf ~/.ccache/*
        
        echo "✅ 清理完成"
        ;;
    
    update)
        echo "更新PX4代码..."
        cd ~/vls_sil/PX4-Autopilot
        git pull origin main
        git submodule sync --recursive
        git submodule update --init --recursive
        echo "✅ 代码更新完成"
        ;;
    
    help|*)
        echo "PX4仿真管理工具"
        echo ""
        echo "用法: ./manage_px4.sh [命令] [选项]"
        echo ""
        echo "命令:"
        echo "  start [选项]     启动仿真 (详情见 run_px4_gazebo.sh -h)"
        echo "  stop [名称]      停止指定容器"
        echo "  restart [选项]   重启仿真"
        echo "  build [目标]     编译PX4"
        echo "  logs [名称]      查看容器日志"
        echo "  bash [名称]      进入容器bash"
        echo "  list            列出所有PX4容器"
        echo "  clean           清理Docker和临时文件"
        echo "  update          更新PX4代码"
        echo "  help            显示此帮助"
        echo ""
        echo "示例:"
        echo "  ./manage_px4.sh start -m typhoon_h480"
        echo "  ./manage_px4.sh bash"
        echo "  ./manage_px4.sh logs"
        echo "  ./manage_px4.sh clean"
        ;;
esac