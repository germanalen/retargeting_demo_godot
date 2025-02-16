@tool
extends Node3D

@export var target_skeleton: Skeleton3D
@export var source_skeleton: Skeleton3D
@export var enabled = true

# target's rest pose is A pose
@export var target_tpose_anim: Animation

# bone_alias : bone_name
var target_bone_name_map = [
	["hip", "CC_Base_Hip"],
	["spine1", "CC_Base_Waist"],
	["spine2", "CC_Base_Spine01"],
	["neck", "CC_Base_NeckTwist01"],
	["head", "CC_Base_Head"],
	
	["r_shoulder", "CC_Base_R_Clavicle"],
	["r_upperarm", "CC_Base_R_Upperarm"],
	["r_forearm", "CC_Base_R_Forearm"],
	["r_hand", "CC_Base_R_Hand"],
	["r_thigh", "CC_Base_R_Thigh"],
	["r_calf", "CC_Base_R_Calf"],
	["r_foot", "CC_Base_R_Foot"],
	["r_toebase", "CC_Base_R_ToeBase"],
	
	["l_shoulder", "CC_Base_L_Clavicle"],
	["l_upperarm", "CC_Base_L_Upperarm"],
	["l_forearm", "CC_Base_L_Forearm"],
	["l_hand", "CC_Base_L_Hand"],
	["l_thigh", "CC_Base_L_Thigh"],
	["l_calf", "CC_Base_L_Calf"],
	["l_foot", "CC_Base_L_Foot"],
	["l_toebase", "CC_Base_L_ToeBase"]
]


# bone_alias : bone_name
var source_bone_name_map = [
	["hip", "mixamorig_Hips"],
	["spine1", "mixamorig_Spine"],
	["spine2", "mixamorig_Spine1"],
	["neck", "mixamorig_Neck"],
	["head", "mixamorig_Head"],
	
	["r_shoulder", "mixamorig_RightShoulder"],
	["r_upperarm", "mixamorig_RightArm"],
	["r_forearm", "mixamorig_RightForeArm"],
	["r_hand", "mixamorig_RightHand"],
	["r_thigh", "mixamorig_RightUpLeg"],
	["r_calf", "mixamorig_RightLeg"],
	["r_foot", "mixamorig_RightFoot"],
	["r_toebase", "mixamorig_RightToeBase"],
	
	["l_shoulder", "mixamorig_LeftShoulder"],
	["l_upperarm", "mixamorig_LeftArm"],
	["l_forearm", "mixamorig_LeftForeArm"],
	["l_hand", "mixamorig_LeftHand"],
	["l_thigh", "mixamorig_LeftUpLeg"],
	["l_calf", "mixamorig_LeftLeg"],
	["l_foot", "mixamorig_LeftFoot"],
	["l_toebase", "mixamorig_LeftToeBase"]
]


var parent_alias = [
	-1,  # 0: hip => none
	 0,  # 1: spine1 => hip
	 1,  # 2: spine2 => spine1
	 2,  # 3: neck => spine2
	 3,  # 4: head => neck
	
	 2,  # 5: r_shoulder => spine2
	 5,  # 6: r_upperarm => r_shoulder
	 6,  # 7: r_forearm => r_upperarm
	 7,  # 8: r_hand => r_forearm
	 0,  # 9: r_thigh => hip
	 9,  # 10: r_calf => r_thigh
	10,  # 11: r_foot => r_calf
	11,  # 12: r_toebase => r_foot
	
	 2,  # 13: l_shoulder => spine2
	13,  # 14: l_upperarm => l_shoulder
	14,  # 15: l_forearm => l_upperarm
	15,  # 16: l_hand => l_forearm
	 0,  # 17: l_thigh => hip
	17,  # 18: l_calf => l_thigh
	18,  # 19: l_foot => l_calf
	19   # 20: l_toebase => l_foot
]


var source_offset_matrices = []
var target_offset_matrices = []



func _ready() -> void:
	assert(len(source_bone_name_map) == len(target_bone_name_map))
	for i in range(len(source_bone_name_map)):
		assert(source_bone_name_map[i][0] == target_bone_name_map[i][0])
	
	var source_model_T_bone_t_poses = calculate_model_T_bone_rest_poses(source_skeleton, source_bone_name_map)
	var target_model_T_bone_t_poses = calculate_model_T_bone_t_poses_from_anim(target_skeleton, target_bone_name_map, target_tpose_anim)
	#target_parent_T_bone_t_poses = calculate_parent_T_bone_rest_poses(target_skeleton, target_bone_name_map)
	
	source_offset_matrices = calculate_offset_matrices(source_model_T_bone_t_poses)
	target_offset_matrices = calculate_offset_matrices(target_model_T_bone_t_poses)

# assumes track paths are of the format "Skeleton3D:bone_name"
func calculate_model_T_bone_t_poses_from_anim(skeleton: Skeleton3D, bone_name_map, anim: Animation):
	var tpose_rotations = {}
	
	var track_count = anim.get_track_count()
	for track_i in range(track_count):
		var track_path = target_tpose_anim.track_get_path(track_i)
		var track_type = target_tpose_anim.track_get_type(track_i)
		
		assert(track_path.get_name_count() > 0)
		var track_path_name = track_path.get_name(0)
		
		if track_path_name == "Skeleton3D" and track_type == Animation.TrackType.TYPE_ROTATION_3D:
			assert(track_path.get_subname_count() == 1)
			var bone_name = track_path.get_subname(0)
			
			var anim_rot: Quaternion = anim.rotation_track_interpolate(track_i, 0)
			
			tpose_rotations[bone_name] = anim_rot
	
	var bone_count = skeleton.get_bone_count()
	var model_T_bone_poses = []
	model_T_bone_poses.resize(bone_count)
	
	
	for bone_id in range(bone_count):
		var bone_name = skeleton.get_bone_name(bone_id)
		
		var model_T_parent = Transform3D.IDENTITY
		var parent_id = skeleton.get_bone_parent(bone_id)
		if parent_id != -1:
			model_T_parent = model_T_bone_poses[parent_id]
		
		var parent_T_bone_rest = skeleton.get_bone_rest(bone_id)			
		
		var parent_T_bone = parent_T_bone_rest
		
		if bone_name in tpose_rotations:
			var anim_rot = tpose_rotations[bone_name]
			parent_T_bone.basis = Basis(anim_rot)
		
		var model_T_bone = model_T_parent * parent_T_bone
		#DebugDraw3D.draw_sphere(model_T_bone.origin, 0.01, Color.WEB_GREEN)
		
		model_T_bone_poses[bone_id] = model_T_bone
	
	
	var model_T_bone_t_poses = []
	model_T_bone_t_poses.resize(len(bone_name_map))
	
	for alias_i in range(len(bone_name_map)):
		var bone_name = bone_name_map[alias_i][1]
		var bone_id = skeleton.find_bone(bone_name)
		assert(bone_id != -1)
		
		model_T_bone_t_poses[alias_i] = model_T_bone_poses[bone_id]
	
	return model_T_bone_t_poses



func calculate_model_T_bone_rest_poses(skeleton, bone_name_map):
	var model_T_bone_rest_poses = []
	model_T_bone_rest_poses.resize(len(bone_name_map))
	
	for alias_i in range(len(bone_name_map)):
		var bone_name = bone_name_map[alias_i][1]
		var bone_id = skeleton.find_bone(bone_name)
		assert(bone_id != -1)
		
		var model_T_bone_t = skeleton.get_bone_global_rest(bone_id)
		model_T_bone_rest_poses[alias_i] = model_T_bone_t
	
	return model_T_bone_rest_poses


func calculate_offset_matrices(model_T_bone_t_poses):
	var alias_count = len(model_T_bone_t_poses)
	
	var offset_matrices = []
	offset_matrices.resize(alias_count)
	
	for alias_i in range(alias_count):
		var model_T_bone = model_T_bone_t_poses[alias_i]
		var model_T_boneadj = Transform3D(Basis.IDENTITY, model_T_bone.origin)
		
		var parent_alias_i = parent_alias[alias_i]
		var model_T_parent = Transform3D.IDENTITY
		if parent_alias_i != -1:
			model_T_parent = model_T_bone_t_poses[parent_alias_i]
		var model_T_parentadj = Transform3D(Basis.IDENTITY, model_T_parent.origin)
		
		var parentadj_T_boneadj = model_T_parentadj.affine_inverse() * model_T_boneadj
		var anim_T_boneadj = parentadj_T_boneadj
		
		var bone_T_boneadj = model_T_bone.affine_inverse() * model_T_boneadj
		
		offset_matrices[alias_i] = {}
		offset_matrices[alias_i].bone_T_boneadj = bone_T_boneadj
		offset_matrices[alias_i].anim_T_boneadj = anim_T_boneadj
	
	return offset_matrices

func _process(_delta: float) -> void:
	var config = DebugDraw3D.new_scoped_config().set_no_depth_test(true)
	config.set_thickness(0.01)
	#const arrow_size = 0.1
	
	var alias_count = len(source_bone_name_map)
	
	if not enabled:
		draw_alias_poses(source_skeleton, source_bone_name_map, source_offset_matrices)
		draw_alias_poses(target_skeleton, target_bone_name_map, target_offset_matrices)
		return
	
	
	draw_gizmo(Transform3D.IDENTITY, [Color.RED, Color.GREEN, Color.BLUE])
	
	
	#var target_model_T_bone_poses = []
	#target_model_T_bone_poses.resize(alias_count)
	
	for alias_i in range(alias_count):
		var parentadj_T_anim = Transform3D.IDENTITY
		
		
		if true:
			var bone_name = source_bone_name_map[alias_i][1]
			var bone_id = source_skeleton.find_bone(bone_name)
			
			var bone_T_boneadj = source_offset_matrices[alias_i].bone_T_boneadj
			var anim_T_boneadj = source_offset_matrices[alias_i].anim_T_boneadj
			
			var model_T_bone = source_skeleton.get_bone_global_pose(bone_id)
			var model_T_boneadj = model_T_bone * bone_T_boneadj
			
			var parent_alias_i = parent_alias[alias_i]
			var model_T_parentadj = Transform3D.IDENTITY
			
			if parent_alias_i != -1:
				var parent_bone_name = source_bone_name_map[parent_alias_i][1]
				
				# this is the "alias parent", not the actual parent in source skeleton
				var parent_id = source_skeleton.find_bone(parent_bone_name) 
				var model_T_parent = source_skeleton.get_bone_global_pose(parent_id)
				
				var parent_T_parentadj: Transform3D = source_offset_matrices[parent_alias_i].bone_T_boneadj
				model_T_parentadj = model_T_parent * parent_T_parentadj
			
			
			parentadj_T_anim = model_T_parentadj.affine_inverse() * model_T_boneadj * anim_T_boneadj.affine_inverse()
			
			draw_gizmo(
				source_skeleton.global_transform * model_T_bone, 
				[Color.DARK_RED, Color.DARK_GREEN, Color.DARK_BLUE]
				)
		
		if true:
			var bone_name = target_bone_name_map[alias_i][1]
			var bone_id = target_skeleton.find_bone(bone_name)
			
			var bone_T_boneadj = target_offset_matrices[alias_i].bone_T_boneadj
			var anim_T_boneadj = target_offset_matrices[alias_i].anim_T_boneadj
			
			var parent_alias_i = parent_alias[alias_i]
			var model_T_parentadj = Transform3D.IDENTITY
			
			if parent_alias_i != -1:
				var parent_bone_name = target_bone_name_map[parent_alias_i][1]
				
				# this is the "alias parent", not the actual parent in source skeleton
				var parent_id = target_skeleton.find_bone(parent_bone_name) 
				var model_T_parent = target_skeleton.get_bone_global_pose(parent_id)
				#var model_T_parent = target_model_T_bone_poses[parent_alias_i]
			
				var parent_T_parentadj: Transform3D = target_offset_matrices[parent_alias_i].bone_T_boneadj
				model_T_parentadj = model_T_parent * parent_T_parentadj
			
			
			var parentadj_T_boneadj = parentadj_T_anim * anim_T_boneadj
			var model_T_boneadj = model_T_parentadj * parentadj_T_boneadj
			var model_T_bone = model_T_boneadj * bone_T_boneadj.affine_inverse()
			#target_model_T_bone_poses[alias_i] = model_T_bone
			draw_gizmo(
				target_skeleton.global_transform * model_T_bone, 
				[Color.DARK_RED, Color.DARK_GREEN, Color.DARK_BLUE]
				)
			
			target_skeleton.set_bone_global_pose(bone_id, model_T_bone)

func draw_alias_poses(skeleton, bone_name_map, offset_matrices):
	var alias_count = len(bone_name_map)
	for alias_i in range(alias_count):
		var bone_name = bone_name_map[alias_i][1]
		var bone_id = skeleton.find_bone(bone_name)
		assert(bone_id != -1)
		
		var bone_T_boneadj = offset_matrices[alias_i].bone_T_boneadj
		var model_T_bone = skeleton.get_bone_global_pose(bone_id)
		
		draw_gizmo(skeleton.global_transform * model_T_bone * bone_T_boneadj, [Color.DARK_RED, Color.DARK_GREEN, Color.DARK_BLUE])

func draw_gizmo(xform: Transform3D, colors: Array, length = 0.1):
	DebugDraw3D.draw_line(xform.origin, xform.origin + xform.basis.x * length, colors[0])
	DebugDraw3D.draw_line(xform.origin, xform.origin + xform.basis.y * length, colors[1])
	DebugDraw3D.draw_line(xform.origin, xform.origin + xform.basis.z * length, colors[2])
