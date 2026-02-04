#!/bin/bash
# manage.sh - 一体化PX4仿真管理

CONTAINER_NAME="px4-sim"
IMAGE_NAME="px4-all-in-one:latest"

case "$1" in
    start)
        shift
        ./run.sh "$@"
        ;;
    
    stop)
        echo "停止仿真..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        echo "✅ 已停止"
        ;;
    
    restart)
        ./manage.sh stop
        sleep 2
        ./manage.sh start "${@:2}"
        ;;
    
    bash)
        echo "进入容器..."
        docker exec -it "$CONTAINER_NAME" bash
        ;;
    
    logs)
        echo "查看日志..."
        docker logs -f "$CONTAINER_NAME"
        ;;
    
    build)
        echo "构建镜像..."
        ./build.sh
        ;;
    
    rebuild)
        echo "重新构建镜像..."
        docker rmi "$IMAGE_NAME" 2>/dev/null || true
        ./build.sh
        ;;
    
    models)
        echo "可用无人机模型:"
        docker exec "$CONTAINER_NAME" bash -c "
            cd /workspace/PX4-Autopilot
            ls Tools/simulation/gz/models/*.sdf 2>/dev/null | xargs -I {} basename {} .sdf | sort
        " 2>/dev/null || echo "请先启动容器"
        ;;
    
    ros)
        echo "ROS2节点..."
        docker exec -it "$CONTAINER_NAME" bash -c "
            source /opt/ros/humble/setup.bash
            ros2 ${@:2}
        "
        ;;
    
    gz)
        echo "Gazebo命令..."
        docker exec -it "$CONTAINER_NAME" bash -c "gz ${@:2}"
        ;;
    
    status)
        echo "容器状态:"
        docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "镜像:"
        docker images | grep "px4-all-in-one"
        ;;
    
    clean)
        echo "清理环境..."
        ./manage.sh stop
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        docker system prune -f
        rm -rf ~/.ros/log/*
        echo "✅ 清理完成"
        ;;
    
    help|*)
        echo "一体化PX4仿真管理工具"
        echo ""
        echo "用法: $0 {命令} [参数]"
        echo ""
        echo "命令:"
        echo "  start [模型] [世界]   启动仿真 (默认: iris empty)"
        echo "  stop                  停止仿真"
        echo "  restart               重启仿真"
        echo "  bash                  进入容器终端"
        echo "  logs                  查看容器日志"
        echo "  build                 构建镜像"
        echo "  rebuild               重新构建镜像"
        echo "  models                查看可用无人机模型"
        echo "  ros [命令]           执行ROS2命令"
        echo "  gz [命令]            执行Gazebo命令"
        echo "  status                查看状态"
        echo "  clean                 清理环境"
        echo "  help                  显示帮助"
        echo ""
        echo "示例:"
        echo "  $0 start iris            # 启动Iris仿真"
        echo "  $0 start typhoon_h480    # 启动Typhoon仿真"
        echo "  $0 bash                  # 进入容器"
        echo "  $0 ros topic list        # 查看ROS话题"
        echo "  $0 gz topic -l           # 查看Gazebo话题"
        echo "  $0 models               # 查看可用模型"
        ;;
esac