
|  版本编号 |  主要修改                            |  镜像大小   |  镜像ID          |上传时间 |
| ---- | ---- | ---- |----|----|
|   v1.7   |   ros-gz-bridge 有问题              |   11.7GB   |  d351e4b7d241   |  2026-02-13   |
|   v1.6   |   update models                    |   11.6GB   |  b17c73ef16ec   |  2026-02-12   |
|   v1.5   |   AP gz models                     |   11.1GB   |  3d9672791da1   |  2026-02-11   |
|   v1.4   |   install_geographiclib_datasets   |   10.5GB   |  51aa66c8cfe7   |  2026-02-11   |
|   v1.3   |   QGC                              |   10.5GB   |  7aac3fe73720   |  2026-02-10   |
|   v1.2   |   nvidia env                       |   9.98GB   |  57de25c051df   |  2026-02-06   |
|   v1.1   |   PX4 make env                     |   8.76GB   |  ed8ee5a0cd6e   |  2026-02-05   |
|   v1.0   |                                    |   9.25GB    |  23d8fc5b5eb5   |  2026-02-02   |

```bash
# start
./px4_start.sh
./ardupilot_start.sh

# stop
./stop_simulation.sh -v ap_container
./stop_simulation.sh -v px4_container

```