#! /bin/bash

# otherwise default to nuttx
if [ -z ${PX4_DOCKER_REPO+x} ]; then
	PX4_DOCKER_REPO="ahao6666/ubuntu_ros2:v1.7"
fi

echo "PX4_DOCKER_REPO: $PX4_DOCKER_REPO";

PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
SRC_DIR=$PWD/../

CCACHE_DIR=${HOME}/.ccache
mkdir -p "${CCACHE_DIR}"

# Get container name from parameter (2nd argument)
CONTAINER_NAME=${2:-}

# Build docker command with optional container name
if [ -n "$CONTAINER_NAME" ]; then
	DOCKER_NAME_OPT="--name $CONTAINER_NAME"
else
	DOCKER_NAME_OPT=""
fi

docker run -d --rm -w "${SRC_DIR}" \
	${DOCKER_NAME_OPT} \
	--gpus all \
	--user="$(id -u):$(id -g)" \
	--device=/dev/dri \
	--device /dev/fuse \
	--env=AWS_ACCESS_KEY_ID \
	--env=AWS_SECRET_ACCESS_KEY \
	--env=BRANCH_NAME \
	--env=CCACHE_DIR="${CCACHE_DIR}" \
	--env=CI \
	--env=CODECOV_TOKEN \
	--env=COVERALLS_REPO_TOKEN \
	--env=PX4_ASAN \
	--env=PX4_MSAN \
	--env=PX4_TSAN \
	--env=PX4_UBSAN \
	--env=TRAVIS_BRANCH \
	--env=TRAVIS_BUILD_ID \
	--env=DISPLAY=${DISPLAY:-:0} \
	--env=QT_X11_NO_MITSHM=1 \
	--publish 14556:14556/udp \
	--privileged \
	--device=/dev/ttyUSB0 \
	--volume=${CCACHE_DIR}:${CCACHE_DIR}:rw \
	--volume=${SRC_DIR}:${SRC_DIR}:rw \
	--volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
	${PX4_DOCKER_REPO} /bin/bash -c "$1"

###########################################
    # docker run -it \
    #     --env="DISPLAY" \
    #     --env="QT_X11_NO_MITSHM=1" \
    #     --env ROS_DOMAIN_ID=0 \
    #     --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    #     --device=/dev/dri \
    #     --device /dev/fuse \
    #     --cap-add SYS_ADMIN \
    #     --security-opt apparmor:unconfined \
    #     --network=host \
    #     --privileged \
    #     --device=/dev/ttyUSB0 \
    #     --user insky \
    #     --name "container_1" \
    #     "ahao6666/ubuntu_ros2:v1.7" \
    #     bash -c "export DISPLAY=:0 && exec bash"
########################################
