from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch_ros.actions import Node
from launch.actions import SetEnvironmentVariable, IncludeLaunchDescription, AppendEnvironmentVariable
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import PathJoinSubstitution
from launch_ros.substitutions import FindPackageShare
from launch.substitutions import Command, PathJoinSubstitution
from launch_ros.parameter_descriptions import ParameterValue

def generate_launch_description():
    ros_gz_sim_pkg_path = get_package_share_directory('ros_gz_sim')
    pkg_path = FindPackageShare('rover_arm')
    gz_launch_path = PathJoinSubstitution([ros_gz_sim_pkg_path, 'launch', 'gz_sim.launch.py'])
    
    arm_description = ParameterValue(
        Command(['xacro ', PathJoinSubstitution([pkg_path, 'urdf', 'arm_assembly_simple.urdf'])]),
        value_type=str,
    )
    rover_description = ParameterValue(
        Command(['xacro ', PathJoinSubstitution([pkg_path, 'urdf', 'rover_drivebase.urdf'])]),
        value_type=str,
    )

    rsp_arm = Node(
        package='robot_state_publisher',
        executable='robot_state_publisher',
        name='rsp_arm',
        parameters=[{'robot_description': arm_description, 'use_sim_time': True}],
        remappings=[('robot_description', 'arm_description')],
        output='screen',
    )

    rsp_rover = Node(
        package='robot_state_publisher',
        executable='robot_state_publisher',
        name='rsp_rover',
        parameters=[{'robot_description': rover_description, 'use_sim_time': True}],
        remappings=[('robot_description', 'rover_description')],
        output='screen',
    )

    spawnArm = Node(
        package='ros_gz_sim',
        executable='create',
        arguments=['-topic', 'arm_description', '-name', 'rover_arm',
                '-x', '0', '-y', '0', '-z', '0.5'],
        output='screen',
    )

    spawnRover = Node(
        package='ros_gz_sim',
        executable='create',
        arguments=['-topic', 'rover_description', '-name', 'rover_drivebase',
                '-x', '0', '-y', '0', '-z', '0.1'],
        output='screen',
    )

    return LaunchDescription([
        AppendEnvironmentVariable(
            'GZ_SIM_RESOURCE_PATH',
            PathJoinSubstitution([pkg_path, '..'])
        ),
        SetEnvironmentVariable(
            'GZ_SIM_PLUGIN_PATH',
            PathJoinSubstitution([pkg_path, 'plugins'])
        ),
        IncludeLaunchDescription(
            PythonLaunchDescriptionSource(gz_launch_path),
            launch_arguments={
                'gz_args': PathJoinSubstitution([pkg_path, 'sdf/world.sdf']),
                'on_exit_shutdown': 'True'
            }.items(),
        ),
        
        rsp_arm,
        rsp_rover,
        spawnArm,
        spawnRover,

        Node(
            package='ros_gz_bridge',
            executable='parameter_bridge',
            arguments=[
                '/clock@rosgraph_msgs/msg/Clock[gz.msgs.Clock',
                '/joint_states@sensor_msgs/msg/JointState@gz.msgs.Model',
                '/tf@tf2_msgs/msg/TFMessage[gz.msgs.Pose_V',
                '/tf_static@tf2_msgs/msg/TFMessage[gz.msgs.Pose_V',
                '/joint_trajectory_controller/joint_trajectory@trajectory_msgs/msg/JointTrajectory@gz.msgs.JointTrajectory',],
            output='screen'
        )
])
