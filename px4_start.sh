#!/bin/bash

# PX4 Gazebo Startup Script
# This script starts a Docker container and runs the PX4 SITL with Gazebo

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source the docker_run.sh script to start the Docker container
# Pass the make command to be executed inside the container
${SCRIPT_DIR}/docker_run.sh "bash"
