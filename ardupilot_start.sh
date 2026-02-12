#!/bin/bash

# Ardupilot Gazebo Startup Script
# This script starts a Docker container and runs the Ardupilot SITL with Gazebo
# Usage: ./ardupilot_start.sh [container_name]

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get container name from parameter, default to 'ap_container'
CONTAINER_NAME=${1:-"ap_container"}

echo "Starting Ardupilot SITL with Gazebo in container: $CONTAINER_NAME"

# Call docker_run.sh to start container in background (keeps running for docker exec commands)
${SCRIPT_DIR}/docker_run.sh "sleep infinity" "$CONTAINER_NAME"

# 根据 SIMULATION 执行不同的操作, iris, alti_transition, alti_transition_windy
SIMULATION="alti_transition_windy"

if [ "$SIMULATION" = "iris" ]; then
  # iris 模型的操作
  echo "启动 iris 模型相关组件..."
  UAV_MODEL="iris_with_zed"
  CAM_LINK_MODEL="zed_camera"
  WORLD_MODEL="iris_runway"
  # 启动 Gazebo 仿真
  sleep 2
  gnome-terminal -- bash -c "docker exec -it ap_container bash -i -c 'source ~/.bashrc && cd ~/src/ardupilot/ && gz sim -v4 -r iris_runway.sdf'; exec bash"
  # 启动 ArduPilot 仿真
  sleep 2
  gnome-terminal -- bash -c "docker exec -it ap_container bash -i -c 'source ~/.bashrc && cd ~/src/ardupilot/ && sim_vehicle.py -v ArduCopter -f gazebo-iris --model JSON --out=127.0.0.1:14540'; exec bash"
#   # 启动参数转发
#   sleep 2
#   gnome-terminal -- bash -c "docker cp config/config_ap_iris.yaml ap_container:/home/insky/ && docker exec -it ap_container bash -c 'export ROS_DOMAIN_ID=$DOMAIN_ID && source ~/.bashrc && ros2 run ros_gz_bridge parameter_bridge --ros-args -p config_file:=/home/insky/config_ap_iris.yaml'; exec bash"

elif [ "$SIMULATION" = "alti_transition" ]; then
  # alti_transition 模型的操作
  echo "启动 alti_transition 模型相关组件..."
  UAV_MODEL="alti_transition_quad"
  CAM_LINK_MODEL="zed_camera"
  WORLD_MODEL="runway"
  # 启动 Gazebo 仿真
  sleep 2
  gnome-terminal -- bash -c "docker exec -it ap_container bash -i -c 'source ~/.bashrc && cd ~/src/ardupilot/ && gz sim -v4 -r alti_transition_runway.sdf'; exec bash"
  # 启动 ArduPilot 仿真
  sleep 2
  gnome-terminal -- bash -c "docker exec -it ap_container bash -i -c 'source ~/.bashrc && cd ~/src/ardupilot/ && sim_vehicle.py -v ArduPlane --model JSON --add-param-file=/home/insky/src/ardupilot_gazebo/config/alti_transition_quad.param --out=127.0.0.1:14540'; exec bash"
#   # 启动参数转发
#   sleep 2
#   gnome-terminal -- bash -c "docker cp config/config_ap_alti_transition_quad.yaml ap_container:/home/insky/ && docker exec -it ap_container bash -c 'export ROS_DOMAIN_ID=$DOMAIN_ID && source ~/.bashrc && ros2 run ros_gz_bridge parameter_bridge --ros-args -p config_file:=/home/insky/config_ap_alti_transition_quad.yaml'; exec bash"

elif [ "$SIMULATION" = "alti_transition_windy" ]; then
  # alti_transition_windy 模型的操作
  echo "启动 alti_transition_windy 模型相关组件..."
  UAV_MODEL="alti_transition_quad"
  CAM_LINK_MODEL="zed_camera"
  WORLD_MODEL="runway"
  # 启动 Gazebo 仿真
  sleep 2
  gnome-terminal -- bash -c "docker exec -it ap_container bash -i -c 'source ~/.bashrc && cd ~/src/ardupilot/ && gz sim -v4 -r alti_transition_windy.sdf'; exec bash"
  # 启动 ArduPilot 仿真
  sleep 2
  gnome-terminal -- bash -c "docker exec -it ap_container bash -i -c 'source ~/.bashrc && cd ~/src/ardupilot/ && sim_vehicle.py -v ArduPlane --model JSON --add-param-file=/home/insky/src/ardupilot_gazebo/config/alti_transition_quad.param --out=127.0.0.1:14540'; exec bash"
#   # 启动参数转发
#   sleep 2
#   gnome-terminal -- bash -c "docker cp config/config_ap_alti_transition_quad.yaml ap_container:/home/insky/ && docker exec -it ap_container bash -c 'export ROS_DOMAIN_ID=$DOMAIN_ID && source ~/.bashrc && ros2 run ros_gz_bridge parameter_bridge --ros-args -p config_file:=/home/insky/config_ap_alti_transition_quad.yaml'; exec bash"

else
  echo "未知的 SIMULATION: $SIMULATION"
  echo "支持的模式: iris, alti_transition, alti_transition_windy"
  exit 1
fi


# 启动 QGroundControl
sleep 2
gnome-terminal -- bash -c "docker exec -it ap_container bash -i -c 'export ROS_DOMAIN_ID=$DOMAIN_ID && cd ~/ && ./QGroundControl-x86_64.AppImage'; exec bash"

# 启动 mavros
sleep 10
gnome-terminal -- bash -c "docker exec -it ap_container bash -i -c 'export ROS_DOMAIN_ID=$DOMAIN_ID && ros2 launch mavros apm.launch fcu_url:=tcp://127.0.0.1:5762\'; exec bash"

# 设置mavros话题发布频率-默认30Hz
sleep 2
gnome-terminal -- bash -c "docker exec -it ap_container bash -i -c \"export ROS_DOMAIN_ID=$DOMAIN_ID && ros2 service call /mavros/set_stream_rate mavros_msgs/srv/StreamRate '{stream_id: 0, message_rate: 30, on_off: true}'\"; exec bash"