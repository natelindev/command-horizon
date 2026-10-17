extends Node3D

# Register construction mesh/material combinations while the match loads, before
# the first live building asks the renderer to compile their surface pipelines.
const Visual = preload("res://source/match/effects/ConstructionVisual.gd")


func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	for style in Visual.STYLES.values():
		var holder = Node3D.new()
		add_child(holder)
		var rig = style.rig.new()
		holder.add_child(rig)
		rig.setup(AABB(Vector3(-2, 0, -2), Vector3(4, 4, 4)))
		var surface = MeshInstance3D.new()
		surface.mesh = rig.mesh(rig.BOX)
		var material = ShaderMaterial.new()
		material.shader = style.shader
		material.set_shader_parameter("total_height", 4.0)
		material.set_shader_parameter("progress", .5)
		var hologram = ShaderMaterial.new()
		hologram.shader = Visual.HOLOGRAM_SHADER
		hologram.set_shader_parameter("total_height", 4.0)
		if style == Visual.STYLES.helix:
			material.next_pass = hologram
		surface.material_override = material
		holder.add_child(surface)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	queue_free()
