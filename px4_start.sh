#!/bin/bash

# PX4 Gazebo Startup Script
# This script starts a Docker container and runs the PX4 SITL with Gazebo
# Usage: ./px4_start.sh [container_name]

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get container name from parameter, default to 'px4_container'
CONTAINER_NAME=${1:-"px4_container"}

echo "Starting PX4 SITL with Gazebo in container: $CONTAINER_NAME"

# Call docker_run.sh with bash and container name
${SCRIPT_DIR}/docker_run.sh "bash" "$CONTAINER_NAME"
