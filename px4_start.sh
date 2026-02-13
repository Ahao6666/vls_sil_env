#!/bin/bash

# PX4 Gazebo Startup Script
# This script starts a Docker container and runs the PX4 SITL with Gazebo
# Usage: ./px4_start.sh [container_name]

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get container name from parameter, default to 'px4_container'
CONTAINER_NAME=${1:-"px4_container"}

echo "Starting PX4 SITL with Gazebo in container: $CONTAINER_NAME"

# Call docker_run.sh to start container in background (keeps running for docker exec commands)
${SCRIPT_DIR}/docker_run.sh "sleep infinity" "$CONTAINER_NAME"


# # 启动 PX4 SITL
# sleep 5

UAV_MODEL="x500_mono_cam_down" #x500_mono_cam_down, x500_stereo_cam, x500_tilt_cam, x500_zed_laser
CAM_LINK_MODEL="${UAV_MODEL}_0"
# 若更换仿真中的飞行平台模型，则需要在修改之后，对下面两行取消注释，首先将本脚运行一下，随后恢复注释。
echo "编译 PX4 SITL 目标模型: ${UAV_MODEL}..."
gnome-terminal -- bash -c "docker exec -it px4_container bash -c 'cd ~/src/PX4-Autopilot && make px4_sitl gz_x500_stereo_cam'; exec bash"

# # 最简单的环境，可选择单二维码/多二维码/H降落标志或V降落标志
# WORLD_MODEL="april_H"   # april, multi_april, april_H, april_V
# gnome-terminal -- bash -c "docker exec -it px4_container bash -c 'export ROS_DOMAIN_ID=$DOMAIN_ID && source ~/.bashrc && cd ~/PX4-Autopilot && PX4_GZ_WORLD=$WORLD_MODEL PX4_GZ_MODEL_POSE="0,0,0,0,0,0" PX4_GZ_MODEL=$UAV_MODEL ./build/px4_sitl_default/bin/px4 '; exec bash"



# # 根据 SIMULATION 执行不同的操作, x500_mono_cam_down, x500_stereo_cam, x500_tilt_cam, x500_zed_laser
# SIMULATION="x500_mono_cam_down"

# if [ "$SIMULATION" = "x500_mono_cam_down" ]; then
#   # x500_mono_cam_down 模型的操作
#   echo "启动 x500_mono_cam_down 模型相关组件..."
#   UAV_MODEL="iris_with_zed"
#   CAM_LINK_MODEL="zed_camera"
#   WORLD_MODEL="iris_runway"
    
# # 启动 Image Bridge
# sleep 2
# gnome-terminal -- bash -c "docker exec -it sil_vls-$VERSION bash -c 'export ROS_DOMAIN_ID=$DOMAIN_ID && source /opt/ros/humble/setup.bash && ros2 run ros_gz_bridge parameter_bridge /world/$WORLD_MODEL/model/$CAM_LINK_MODEL/link/camera_link/sensor/imager/image@sensor_msgs/msg/Image@gz.msgs.Image'; exec bash"

# # 启动 CameraInfo Bridge
# sleep 2
# gnome-terminal -- bash -c "docker exec -it sil_vls-$VERSION bash -c 'export ROS_DOMAIN_ID=$DOMAIN_ID && source ~/.bashrc && ros2 run ros_gz_bridge parameter_bridge /world/$WORLD_MODEL/model/$CAM_LINK_MODEL/link/camera_link/sensor/imager/camera_info@sensor_msgs/msg/CameraInfo@gz.msgs.CameraInfo'; exec bash"

# # 启动图像压缩转发
# sleep 2
# gnome-terminal -- bash -c "docker exec -it sil_vls-$VERSION bash -c 'export ROS_DOMAIN_ID=$DOMAIN_ID && source ~/.bashrc && ros2 run image_transport republish raw compressed --ros-args -r in:=/world/$WORLD_MODEL/model/$CAM_LINK_MODEL/link/camera_link/sensor/imager/image -r /out/compressed:=/$UAV_MODEL/image_raw/compressed'; exec bash"

# elif [ "$SIMULATION" = "alti_transition" ]; then
#   # alti_transition 模型的操作
#   echo "启动 alti_transition 模型相关组件..."
#   UAV_MODEL="alti_transition_quad"
#   CAM_LINK_MODEL="zed_camera"
#   WORLD_MODEL="runway"
#   # 启动 Gazebo 仿真
#   sleep 2
#   gnome-terminal -- bash -c "docker exec -it ap_container bash -i -c 'source ~/.bashrc && cd ~/src/ardupilot/ && gz sim -v4 -r alti_transition_runway.sdf'; exec bash"
#   # 启动 ArduPilot 仿真
#   sleep 2
#   gnome-terminal -- bash -c "docker exec -it ap_container bash -i -c 'source ~/.bashrc && cd ~/src/ardupilot/ && sim_vehicle.py -v ArduPlane --model JSON --add-param-file=/home/insky/src/ardupilot_gazebo/config/alti_transition_quad.param --out=127.0.0.1:14540'; exec bash"
# #   # 启动参数转发
# #   sleep 2
# #   gnome-terminal -- bash -c "docker cp config/config_ap_alti_transition_quad.yaml ap_container:/home/insky/ && docker exec -it ap_container bash -lic 'export ROS_DOMAIN_ID=$DOMAIN_ID && source ~/.bashrc && ros2 run ros_gz_bridge parameter_bridge --ros-args -p config_file:=/home/insky/config_ap_alti_transition_quad.yaml'; exec bash"

# elif [ "$SIMULATION" = "alti_transition_windy" ]; then
#   # alti_transition_windy 模型的操作
#   echo "启动 alti_transition_windy 模型相关组件..."
#   UAV_MODEL="alti_transition_quad"
#   CAM_LINK_MODEL="zed_camera"
#   WORLD_MODEL="runway"
#   # 启动 Gazebo 仿真
#   sleep 2
#   gnome-terminal -- bash -c "docker exec -it ap_container bash -i -c 'source ~/.bashrc && cd ~/src/ardupilot/ && gz sim -v4 -r alti_transition_windy.sdf'; exec bash"
#   # 启动 ArduPilot 仿真
#   sleep 2
#   gnome-terminal -- bash -c "docker exec -it ap_container bash -i -c 'source ~/.bashrc && cd ~/src/ardupilot/ && sim_vehicle.py -v ArduPlane --model JSON --add-param-file=/home/insky/src/ardupilot_gazebo/config/alti_transition_quad.param --out=127.0.0.1:14540'; exec bash"
#   # # 启动参数转发
#   # sleep 2
#   # gnome-terminal -- bash -c "docker cp config/config_ap_alti_transition_quad.yaml ap_container:/home/insky/ && docker exec -it ap_container bash -ic 'export ROS_DOMAIN_ID=$DOMAIN_ID && source ~/.bashrc && ros2 run ros_gz_bridge parameter_bridge --ros-args -p config_file:=/home/insky/config_ap_alti_transition_quad.yaml'; exec bash"

# else
#   echo "未知的 SIMULATION: $SIMULATION"
#   echo "支持的模式: iris, alti_transition, alti_transition_windy"
#   exit 1
# fi