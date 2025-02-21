# retargeting_demo_godot
A godot 4.3 project with a basic retargeting script.

Demo: https://youtu.be/1Dv5aGXxGE8?si=8It4sFlwJFd8O2GB  
Explanation: https://youtu.be/S5HEf6v7hlE?si=ym_BCAbZ2jTZ4Clc

It works by precomputing offset matrices from t-poses to bridge the pose between 2 skeletons and then copying local rotations in the appropriate common coordinate space from source skeleton to target skeleton.
No IK is used here.
