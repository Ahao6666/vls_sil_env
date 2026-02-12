#!/bin/bash

# 默认参数值
VERSION=""

# 解析命令行参数
while [ $# -gt 0 ]; do
  case $1 in
    -v|--version)
      VERSION="$2"
      shift 2
      ;;
    *)
      echo "[ERROR] Unknown parameter: $1"
      echo "Usage: ./stop_simulation.sh [-v|--version VERSION]"
      exit 1
      ;;
  esac
done

# 检查版本参数是否提供
if [ -z "$VERSION" ]; then
  echo "[ERROR] Version parameter is required"
  echo "Usage: ./stop_simulation.sh [-v|--version VERSION]"
  exit 1
fi

echo "[INFO] Stopping simulation environment..."

# Stop Docker container
echo "[INFO] Stopping Docker container $VERSION..."
if docker ps -q --filter "name=$VERSION" | grep -q .; then
    docker stop $VERSION
    echo "[INFO] Docker container $VERSION stopped"
else
    echo "[WARNING] No running Docker container $VERSION found"
fi

# Precisely close other terminal windows
echo "[INFO] Closing other terminal windows..."
if command -v xdotool &> /dev/null; then
    # Get current active window ID
    current_window=$(xdotool getactivewindow)
    
    # Get all terminal window IDs
    terminal_windows=$(xdotool search --class "gnome-terminal")
    count=0
    
    for window_id in $terminal_windows; do
        if [ "$window_id" != "$current_window" ]; then
            xdotool windowclose "$window_id" 2>/dev/null
            count=$((count+1))
        fi
    done
    echo "[INFO] Closed $count other terminal windows"
else
    echo "[WARNING] xdotool not installed, cannot precisely close terminal windows"
    echo "Suggested installation: sudo apt-get install xdotool"
fi

# Clean up possible residual processes
echo "[INFO] Cleaning up residual processes..."
pkill -f "docker exec.*$VERSION" 2>/dev/null
pkill -f "bash -c.*$VERSION" 2>/dev/null

# Restore X server access permissions (remove current host access)
xhost -local:$(hostname) 2>/dev/null

echo "[INFO] Simulation environment stopped"