#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import QuaternionStamped, TwistStamped, Vector3Stamped, PoseStamped
from sensor_msgs.msg import Imu, BatteryState
from sensor_msgs.msg import NavSatFix
from rclpy.qos import QoSProfile, QoSHistoryPolicy, QoSReliabilityPolicy, QoSDurabilityPolicy
import math
import yaml
from pathlib import Path

class Mavros2TeleConverter(Node):
    def __init__(self):
        super().__init__('Mavros2TeleConverter')
        self.get_logger().info('Start Mavros2TeleConverter')
        # 读取话题配置文件（config/topics.yaml）。如果不存在则使用默认值。
        config_path = Path(__file__).resolve().parent.parent / 'config' / 'topics.yaml'
        topics_cfg = {}
        try:
            with open(config_path, 'r') as f:
                cfg = yaml.safe_load(f) or {}
                topics_cfg = cfg.get('topics', {})
        except Exception as e:
            self.get_logger().warning(f'无法加载话题配置 {config_path}: {e}')

        input_topics = topics_cfg.get('input', {})
        output_topics = topics_cfg.get('output', {})
        # 定义QoS配置 - 使用BEST_EFFORT以匹配MAVROS IMU数据
        qos_profile = QoSProfile(
            depth=10,  # 队列深度
            reliability=QoSReliabilityPolicy.BEST_EFFORT,  # IMU数据通常使用BEST_EFFORT
            durability=QoSDurabilityPolicy.VOLATILE,  # 非持久化
            history=QoSHistoryPolicy.KEEP_LAST  # 保留最新消息
        )

        # 创建订阅者，订阅 IMU
        self.subscription_imu = self.create_subscription(
            Imu,
            input_topics.get('imu', '/mavros/imu/data'),
            self.imu_callback,
            qos_profile
        )        
        # 创建订阅者，订阅 pose
        self.subscription_pose = self.create_subscription(
            PoseStamped,
            input_topics.get('pose', '/mavros/local_position/pose'),
            self.pose_callback,
            qos_profile
        )
        # 创建订阅者，订阅 body velocity
        self.subscription_vel = self.create_subscription(
            TwistStamped,
            input_topics.get('vel_body', '/mavros/local_position/velocity_body'),
            self.velocity_body_callback,
            qos_profile
        )
        # 创建订阅者，订阅 global position
        self.subscription_g_position = self.create_subscription(
            NavSatFix,
            input_topics.get('global', '/mavros/global_position/global'),
            self.g_position_callback,
            qos_profile
        )
        # 创建订阅者，订阅 local velocity
        self.subscription_local_vel = self.create_subscription(
            TwistStamped,
            input_topics.get('local_vel', '/mavros/local_position/velocity_local'),
            self.local_vel_callback,
            qos_profile
        )
        # 创建订阅者，订阅 battery
        self.subscription_battery = self.create_subscription(
            BatteryState,
            input_topics.get('battery', '/mavros/battery'),
            self.battery_callback,
            qos_profile
        )
        # 发布者配置
        publisher_qos = QoSProfile(
            depth=10,
            reliability=QoSReliabilityPolicy.RELIABLE,  # 输出使用RELIABLE
            durability=QoSDurabilityPolicy.VOLATILE,
            history=QoSHistoryPolicy.KEEP_LAST
        )
        
        # publish /telemetry/attitude {Quaternion (w x y z)}
        self.publisher_att = self.create_publisher(
            QuaternionStamped,
            output_topics.get('attitude', '/telemetry/attitude'),
            publisher_qos
        )
        # publish /telemetry/vel_body {Body-frame XYZ velocity (m * s⁻¹)}
        self.publisher_vel_body = self.create_publisher(
            TwistStamped,
            output_topics.get('vel_body', '/telemetry/vel_body'),
            publisher_qos
        )
        # publish /telemetry/global_position/global {Lat/Lon/Alt from GNSS receiver}
        self.publisher_g_position = self.create_publisher(
            NavSatFix,
            output_topics.get('global', '/telemetry/global_position/global'),
            publisher_qos
        )
        # publish /telemetry/angular_rate {Body-frame angular rate (rad * s⁻¹)}
        self.publisher_angular_rate = self.create_publisher(
            Vector3Stamped,
            output_topics.get('angular_rate', '/telemetry/angular_rate'),
            publisher_qos
        )
        # publish /telemetry/local_position/vel {NED-frame XYZ velocity (m * s⁻¹)}
        self.publisher_vel_local = self.create_publisher(
            TwistStamped,
            output_topics.get('local_vel', '/telemetry/local_position/vel'),
            publisher_qos
        )
        # publish /telemetry/accel {Body-frame XYZ acceleration (m * s⁻²)}
        self.publisher_acc = self.create_publisher(
            Vector3Stamped,
            output_topics.get('accel', '/telemetry/accel'),
            publisher_qos
        )
        # publish /telemetry/battery_state {Whole voltage + per-cell voltages}
        self.publisher_battery = self.create_publisher(
            BatteryState,
            output_topics.get('battery_state', '/telemetry/battery_state'),
            publisher_qos
        )
    
    def normalize_angle(self, angle):
        """将角度限制在[-π, π]范围内"""
        return ((angle + math.pi) % (2 * math.pi)) - math.pi
    
    def euler_from_quaternion(self, x, y, z, w):
        """
        将四元数转换为欧拉角 (roll, pitch, yaw)
        使用ROS标准顺序: 绕x轴(roll), 绕y轴(pitch), 绕z轴(yaw)
        """
        # 滚转角 (x-axis rotation)
        sinr_cosp = 2.0 * (w * x + y * z)
        cosr_cosp = 1.0 - 2.0 * (x * x + y * y)
        roll = math.atan2(sinr_cosp, cosr_cosp)
        
        # 俯仰角 (y-axis rotation)
        sinp = 2.0 * (w * y - z * x)
        if abs(sinp) >= 1:
            pitch = math.copysign(math.pi / 2, sinp)
        else:
            pitch = math.asin(sinp)
        
        # 偏航角 (z-axis rotation)
        siny_cosp = 2.0 * (w * z + x * y)
        cosy_cosp = 1.0 - 2.0 * (y * y + z * z)
        yaw = math.atan2(siny_cosp, cosy_cosp)
        
        return roll, pitch, yaw
    
    def quaternion_from_euler(self, roll, pitch, yaw):
        """
        将欧拉角转换为四元数
        使用ROS标准顺序: 绕x轴(roll), 绕y轴(pitch), 绕z轴(yaw)
        """
        cy = math.cos(yaw * 0.5)
        sy = math.sin(yaw * 0.5)
        cp = math.cos(pitch * 0.5)
        sp = math.sin(pitch * 0.5)
        cr = math.cos(roll * 0.5)
        sr = math.sin(roll * 0.5)
        
        w = cr * cp * cy + sr * sp * sy
        x = sr * cp * cy - cr * sp * sy
        y = cr * sp * cy + sr * cp * sy
        z = cr * cp * sy - sr * sp * cy
        
        return [x, y, z, w]
    
    def enu_to_ned_euler(self, roll_enu, pitch_enu, yaw_enu):
        """将ENU欧拉角转换为NED欧拉角"""
        # roll和pitch保持不变
        roll_ned = roll_enu
        pitch_ned = pitch_enu
        yaw_ned = (yaw_enu - math.pi/2) * (-1)
        
        # 标准化到[-π, π]
        roll_ned = self.normalize_angle(roll_ned)
        pitch_ned = self.normalize_angle(pitch_ned)
        yaw_ned = self.normalize_angle(yaw_ned)
        return roll_ned, pitch_ned, yaw_ned
    
    def imu_callback(self, msg):
        """处理接收到的pose消息"""
        try:
            # 创建加速度消息并发布
            output_msg_acc = Vector3Stamped()
            output_msg_acc.header = msg.header
            output_msg_acc.vector.x = msg.linear_acceleration.x
            output_msg_acc.vector.y = msg.linear_acceleration.y
            output_msg_acc.vector.z = msg.linear_acceleration.z * (-1)
            self.publisher_acc.publish(output_msg_acc)

        except Exception as e:
            self.get_logger().error(f'处理消息时出错: {e}')

    def pose_callback(self, msg):
        """处理接收到的pose消息"""
        try:
            # 提取四元数（来自pose消息的orientation字段）
            q_in = msg.pose.orientation           
            # 将四元数转换为欧拉角
            roll, pitch, yaw = self.euler_from_quaternion(
                q_in.x, q_in.y, q_in.z, q_in.w
            )
            
            # 转换为NED欧拉角
            roll_ned, pitch_ned, yaw_ned = self.enu_to_ned_euler(roll, pitch, yaw)
            # 存储结果
            self.nn_roll = roll_ned
            self.nn_pitch = -pitch_ned
            self.nn_yaw = yaw_ned
            # self.get_logger().info(f'输出(r,p,y)=({self.nn_roll:.3f},\t{self.nn_pitch:.3f},\t{self.nn_yaw:.3f})')
            # 将欧拉角转换回四元数
            output_quaternion = self.quaternion_from_euler(self.nn_roll, self.nn_pitch, self.nn_yaw)
            
            # 创建并填充输出消息
            output_msg = QuaternionStamped()
            output_msg.header = msg.header
            output_msg.quaternion.x = output_quaternion[0]
            output_msg.quaternion.y = output_quaternion[1]
            output_msg.quaternion.z = output_quaternion[2]
            output_msg.quaternion.w = output_quaternion[3]
            
            # 发布消息
            self.publisher_att.publish(output_msg)

        except Exception as e:
            self.get_logger().error(f'处理消息时出错: {e}')

    def velocity_body_callback(self, msg):
        """处理接收到的angular_rate消息"""
        try:
            # 创建并填充输出消息
            output_msg_linear = TwistStamped()
            output_msg_linear.header = msg.header
            output_msg_linear.twist.linear.x = msg.twist.linear.x
            output_msg_linear.twist.linear.y = msg.twist.linear.y
            output_msg_linear.twist.linear.z = msg.twist.linear.z

            output_msg_angular = Vector3Stamped()
            output_msg_angular.header = msg.header
            output_msg_angular.vector.x = msg.twist.angular.x
            output_msg_angular.vector.y = msg.twist.angular.y
            output_msg_angular.vector.z = msg.twist.angular.z
            # 发布消息
            self.publisher_vel_body.publish(output_msg_linear)
            self.publisher_angular_rate.publish(output_msg_angular)
            
        except Exception as e:
            self.get_logger().error(f'处理消息时出错: {e}')

    def battery_callback(self, msg):
        """处理接收到的BatteryState消息"""
        try:
            # 创建并填充输出消息
            output_msg = BatteryState()
            output_msg = msg
            # 发布消息
            self.publisher_battery.publish(output_msg)
            
        except Exception as e:
            self.get_logger().error(f'处理消息时出错: {e}')

    def g_position_callback(self, msg):
        """处理接收到的velocity_body消息"""
        try:
            # 创建并填充输出消息
            output_msg = NavSatFix()
            output_msg.header = msg.header
            output_msg.latitude = msg.latitude
            output_msg.longitude = msg.longitude
            output_msg.altitude = msg.altitude
            
            # 复制协方差
            output_msg.position_covariance = msg.position_covariance
            output_msg.position_covariance_type = msg.position_covariance_type
            
            # 发布消息
            self.publisher_g_position.publish(output_msg)
            
        except Exception as e:
            self.get_logger().error(f'处理消息时出错: {e}')

    def local_vel_callback(self, msg):
        """处理接收到的velocity_local消息"""
        try:
            # 创建并填充输出消息
            output_msg_linear = TwistStamped()
            output_msg_linear.header = msg.header
            output_msg_linear.twist.linear.x = msg.twist.linear.y
            output_msg_linear.twist.linear.y = msg.twist.linear.x
            output_msg_linear.twist.linear.z = msg.twist.linear.z * (-1)

            # 发布消息
            self.publisher_vel_local.publish(output_msg_linear)
            
        except Exception as e:
            self.get_logger().error(f'处理消息时出错: {e}')

def main(args=None):
    rclpy.init(args=args)
    
    converter = Mavros2TeleConverter()
    
    try:
        rclpy.spin(converter)
    except KeyboardInterrupt:
        converter.get_logger().info('接收到终止信号')
    finally:
        converter.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()