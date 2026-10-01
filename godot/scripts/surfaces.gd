extends RefCounted

var cache: Dictionary = {}


func textured(asset: String, tint: Color = Color.WHITE, density: float = 0.35) -> StandardMaterial3D:
	var key := asset + str(tint) + str(density)
	if cache.has(key):
		return cache[key]
	var material := StandardMaterial3D.new()
	var folder := "res://assets/textures/%s/" % asset
	material.albedo_texture = load(folder + "diff.jpg")
	material.normal_enabled = true
	material.normal_texture = load(folder + "nor_gl.jpg")
	material.normal_scale = 0.8
	material.roughness_texture = load(folder + "rough.jpg")
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.albedo_color = tint
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * density
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	cache[key] = material
	return material


func plain(color: Color, roughness: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var key := str(color) + str(roughness) + str(metal)
	if cache.has(key):
		return cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metal
	cache[key] = material
	return material
