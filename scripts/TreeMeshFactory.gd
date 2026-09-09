class_name TreeMeshFactory
extends RefCounted

## Compiles and provides static, low-poly tree mesh variations with rich organic morphology:
## - Archetype 1: Classic Umbrella Canopy Tree (dossel aberto, galhos espalhados lateralmente com curvatura, cúpula ampla)
## - Archetype 2: V-Bifurcated Native Tree (tronco bifurcado em V logo na base, copas duplas entrelaçadas)
## - Archetype 3: Old Gnarled Crooked Tree (tronco grosso inclinado, bacias assimétricas retorcidas e galho seco inferior)
## - Archetype 4: Young Slender Tree (tronco fino, copa alta e compacta para preenchimento vertical)
## - Archetype 5: Tall Multi-Tier Dense Tree (tronco alto com andares horizontais de galhos e copa emergente)
## - Archetype 6: Dead Standing Tree (esquelética bare wood, galhos quebrados pontiagudos, casca cinzenta, 0 folhas)
## - Archetype 7: Dead Broken Trunk (tronco partido ao meio a ~4.8m com lascas e pontas pontiagudas, casca cinzenta, 0 folhas)
## - Volumetric 3D leaf cards: clusters com rotações completas em Roll, Pitch e Yaw, incluindo planos inclinados para cima e para baixo.

var cached_living_variations: Array[Mesh] = []
var cached_dead_variations: Array[Mesh] = []


func get_living_tree_variations() -> Array[Mesh]:
	if not cached_living_variations.is_empty():
		return cached_living_variations
	_load_or_compile_all()
	return cached_living_variations


func get_dead_tree_variations() -> Array[Mesh]:
	if not cached_dead_variations.is_empty():
		return cached_dead_variations
	_load_or_compile_all()
	return cached_dead_variations


func get_tree_variations() -> Array[Mesh]:
	return get_living_tree_variations()


func _load_or_compile_all() -> void:
	if not cached_living_variations.is_empty() and not cached_dead_variations.is_empty():
		return

	var live_paths = [
		"res://assets/models/tree_variation_1.tres",
		"res://assets/models/tree_variation_2.tres",
		"res://assets/models/tree_variation_3.tres",
		"res://assets/models/tree_variation_4.tres",
		"res://assets/models/tree_variation_5.tres"
	]
	var dead_paths = [
		"res://assets/models/tree_dead_1.tres",
		"res://assets/models/tree_dead_2.tres"
	]

	var all_loaded = true
	var loaded_live: Array[Mesh] = []
	for p in live_paths:
		if ResourceLoader.exists(p):
			var m = load(p) as Mesh
			if m != null:
				loaded_live.append(m)
			else:
				all_loaded = false
		else:
			all_loaded = false

	var loaded_dead: Array[Mesh] = []
	for p in dead_paths:
		if ResourceLoader.exists(p):
			var m = load(p) as Mesh
			if m != null:
				loaded_dead.append(m)
			else:
				all_loaded = false
		else:
			all_loaded = false

	if all_loaded and loaded_live.size() == 5 and loaded_dead.size() == 2:
		cached_living_variations = loaded_live
		cached_dead_variations = loaded_dead
		return

	compile_and_cache_variations()


func compile_and_cache_variations() -> Array[Mesh]:
	cached_living_variations.clear()
	cached_dead_variations.clear()

	# Variation 1: Classic Umbrella Canopy Tree (dossel aberto, galhos espalhados lateralmente)
	var m1 = _build_umbrella_canopy_tree(101)
	ResourceSaver.save(m1, "res://assets/models/tree_variation_1.tres")
	cached_living_variations.append(m1)

	# Variation 2: V-Bifurcated Native Tree (tronco bifurcado em V logo abaixo)
	var m2 = _build_v_bifurcated_tree(202)
	ResourceSaver.save(m2, "res://assets/models/tree_variation_2.tres")
	cached_living_variations.append(m2)

	# Variation 3: Old Gnarled Crooked Tree (tronco grosso, torto, galhos assimétricos)
	var m3 = _build_thick_gnarled_tree(303)
	ResourceSaver.save(m3, "res://assets/models/tree_variation_3.tres")
	cached_living_variations.append(m3)

	# Variation 4: Young Slender Tree (esguia, copa alta e compacta)
	var m4 = _build_young_slender_tree(404)
	ResourceSaver.save(m4, "res://assets/models/tree_variation_4.tres")
	cached_living_variations.append(m4)

	# Variation 5: Tall Multi-Tier Dense Tree (tronco alto com andares verticais de galhos)
	var m5 = _build_tall_multitier_tree(505)
	ResourceSaver.save(m5, "res://assets/models/tree_variation_5.tres")
	cached_living_variations.append(m5)

	# Dead 1: Dead Standing Tree (esquelética, galhos quebrados, casca cinzenta)
	var d1 = _build_dead_standing_tree(606)
	ResourceSaver.save(d1, "res://assets/models/tree_dead_1.tres")
	cached_dead_variations.append(d1)

	# Dead 2: Dead Broken Trunk (tronco partido ao meio com lascas visíveis)
	var d2 = _build_dead_broken_trunk(707)
	ResourceSaver.save(d2, "res://assets/models/tree_dead_2.tres")
	cached_dead_variations.append(d2)

	# Update fallback lowpoly_tree.tres
	ResourceSaver.save(m1, "res://assets/models/lowpoly_tree.tres")

	return cached_living_variations


## -----------------------------------------------------------------------------
## ARQUÉTIPO 1: Copa Guarda-Chuva Clássica (Umbrella Canopy Tree)
## Tronco robusto, galhos superiores espalham lateralmente com curvatura para fora
## antes de subir, cúpula ampla (dossel aberto), ramificações terciárias e ramos cruzados
## -----------------------------------------------------------------------------
func _build_umbrella_canopy_tree(seed_val: int) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var st_bark = SurfaceTool.new()
	st_bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_foliage = SurfaceTool.new()
	st_foliage.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sides = 6
	var r_base = 0.50

	# 1. Tronco principal contínuo até o nó central da copa (~6.5m)
	var p0 = Vector3.ZERO
	var p1 = Vector3(rng.randf_range(-0.15, 0.15), 2.2, rng.randf_range(-0.15, 0.15))
	var p2 = Vector3(rng.randf_range(-0.25, 0.25), 4.6, rng.randf_range(-0.25, 0.25))
	var p_hub = Vector3(rng.randf_range(-0.15, 0.15), 6.5, rng.randf_range(-0.15, 0.15))

	_build_continuous_branch(st_bark, [p0, p1, p2, p_hub], [r_base, r_base * 0.88, r_base * 0.74, r_base * 0.62], sides, true, false)

	# Galho seco baixo saindo a 2.6m
	var dry_dir = Vector3(rng.randf_range(0.6, 0.9), rng.randf_range(-0.1, 0.15), rng.randf_range(-0.4, 0.4)).normalized()
	_build_cylinder_segment(st_bark, p1 + Vector3(0, 0.4, 0), p1 + Vector3(0, 0.4, 0) + dry_dir * 1.7, 0.15, 0.03, 4)

	# 2. Quatro galhos primários estilo guarda-chuva espalhando lateralmente
	var bough_tips: Array[Vector3] = []
	for i in range(4):
		var ang = float(i) * (TAU / 4.0) + rng.randf_range(-0.25, 0.25)
		var bough_reach = rng.randf_range(3.8, 4.6)
		# Espalha lateralmente para fora com leve subida
		var bough_mid = p_hub + Vector3(cos(ang) * bough_reach, rng.randf_range(0.8, 1.4), sin(ang) * bough_reach)
		_build_continuous_branch(st_bark, [p_hub, bough_mid], [0.26, 0.17], sides, true, true)

		# Dois galhos secundários curvando para fora e para cima
		for s in range(2):
			var sec_ang = ang + (float(s) - 0.5) * 0.75 + rng.randf_range(-0.15, 0.15)
			var sec_reach = rng.randf_range(2.6, 3.4)
			var sec_tip = bough_mid + Vector3(cos(sec_ang) * sec_reach, rng.randf_range(1.2, 2.0), sin(sec_ang) * sec_reach)

			# Ramificação primária contínua até o tufo de folhas
			var tert_ang0 = sec_ang - 0.35 + rng.randf_range(-0.1, 0.1)
			var tert_tip0 = sec_tip + Vector3(cos(tert_ang0) * rng.randf_range(1.5, 2.2), rng.randf_range(0.4, 1.1), sin(tert_ang0) * rng.randf_range(1.5, 2.2))
			_build_continuous_branch(st_bark, [bough_mid, sec_tip, tert_tip0], [0.17, 0.10, 0.01], 4, true, true)
			_add_volumetric_foliage_cards(st_foliage, tert_tip0, rng.randf_range(4.0, 4.8), rng, 2)

			# Ramo secundário lateral bifurcando no nó sec_tip
			var tert_ang1 = sec_ang + 0.40 + rng.randf_range(-0.1, 0.1)
			var tert_tip1 = sec_tip + Vector3(cos(tert_ang1) * rng.randf_range(1.5, 2.2), rng.randf_range(0.4, 1.1), sin(tert_ang1) * rng.randf_range(1.5, 2.2))
			_build_cylinder_segment(st_bark, sec_tip, tert_tip1, 0.08, 0.01, 4)
			_add_volumetric_foliage_cards(st_foliage, tert_tip1, rng.randf_range(4.0, 4.8), rng, 2)

			_add_volumetric_foliage_cards(st_foliage, sec_tip, rng.randf_range(3.8, 4.4), rng, 2)

		bough_tips.append(bough_mid)

	# 3. Galhos diagonais cruzando no terço superior para fechar o teto visual
	if bough_tips.size() >= 4:
		var cross1_start = bough_tips[0].lerp(p_hub, 0.3)
		var cross1_end = bough_tips[2].lerp(p_hub, 0.3) + Vector3(0, rng.randf_range(0.5, 1.2), 0)
		_build_cylinder_segment(st_bark, cross1_start, cross1_end, 0.14, 0.08, 4)
		_add_volumetric_foliage_cards(st_foliage, cross1_start.lerp(cross1_end, 0.5), rng.randf_range(3.8, 4.4), rng, 2)

		var cross2_start = bough_tips[1].lerp(p_hub, 0.3)
		var cross2_end = bough_tips[3].lerp(p_hub, 0.3) + Vector3(0, rng.randf_range(0.5, 1.2), 0)
		_build_cylinder_segment(st_bark, cross2_start, cross2_end, 0.14, 0.08, 4)
		_add_volumetric_foliage_cards(st_foliage, cross2_start.lerp(cross2_end, 0.5), rng.randf_range(3.8, 4.4), rng, 2)

	# 4. Cúpula central
	var apex_top = p_hub + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(3.2, 4.0), rng.randf_range(-0.2, 0.2))
	_build_cylinder_segment(st_bark, p_hub, apex_top, 0.20, 0.08, sides)
	_add_volumetric_foliage_cards(st_foliage, apex_top, rng.randf_range(4.2, 4.8), rng, 3)

	return _finalize_tree_mesh(st_bark, st_foliage, Color(0.24, 0.17, 0.11))


## -----------------------------------------------------------------------------
## ARQUÉTIPO 2: Bifurcada em "V" (V-Bifurcated Native Tree)
## Tronco se divide cedo (~2.3m) em dois eixos dominantes com copas cheias
## -----------------------------------------------------------------------------
func _build_v_bifurcated_tree(seed_val: int) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var st_bark = SurfaceTool.new()
	st_bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_foliage = SurfaceTool.new()
	st_foliage.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sides = 6
	var r_base = 0.52

	# 1. Base contínua até a bifurcação em V (~2.3m)
	var p0 = Vector3.ZERO
	var p1 = Vector3(rng.randf_range(-0.15, 0.15), 1.2, rng.randf_range(-0.15, 0.15))
	var split_pt = Vector3(rng.randf_range(-0.25, 0.25), 2.3, rng.randf_range(-0.25, 0.25))

	_build_continuous_branch(st_bark, [p0, p1, split_pt], [r_base, r_base * 0.90, r_base * 0.82], sides, true, true)

	# Galho seco na base
	var dry_dir1 = Vector3(rng.randf_range(0.6, 0.9), rng.randf_range(-0.1, 0.2), rng.randf_range(-0.4, 0.4)).normalized()
	_build_cylinder_segment(st_bark, p1 + Vector3(0, 0.4, 0), p1 + Vector3(0, 0.4, 0) + dry_dir1 * 1.8, 0.16, 0.03, 4)

	# 2. Dois braços em V divergentes
	var v_angles = [rng.randf_range(-0.2, 0.2), rng.randf_range(PI - 0.25, PI + 0.25)]
	var arm_mids: Array[Vector3] = []
	for a_idx in range(2):
		var ang = v_angles[a_idx]
		var v_lean = Vector3(cos(ang) * 0.50, 0.95, sin(ang) * 0.50).normalized()

		var arm_len1 = rng.randf_range(4.0, 4.8)
		var p_arm_mid = split_pt + v_lean * arm_len1 + Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		_build_cylinder_segment(st_bark, split_pt, p_arm_mid, r_base * 0.58, r_base * 0.42, sides)
		arm_mids.append(p_arm_mid)

		# Galho seco lateral
		if rng.randf() > 0.35:
			var dead_dir = Vector3(sin(ang), rng.randf_range(0.1, 0.35), cos(ang)).normalized()
			_build_cylinder_segment(st_bark, p_arm_mid, p_arm_mid + dead_dir * 1.7, 0.13, 0.03, 4)

		# Galhos secundários contínuos
		for sub_b in range(2):
			var sub_ang = ang + (float(sub_b) - 0.5) * 0.85 + rng.randf_range(-0.15, 0.15)
			var sub_dir = Vector3(cos(sub_ang) * 0.65, 0.80, sin(sub_ang) * 0.65).normalized()
			var sec_tip = p_arm_mid + sub_dir * rng.randf_range(3.8, 4.8)

			var tert_ang0 = sub_ang - 0.4 + rng.randf_range(-0.1, 0.1)
			var tert_tip0 = sec_tip + Vector3(cos(tert_ang0) * rng.randf_range(1.4, 2.0), rng.randf_range(0.5, 1.2), sin(tert_ang0) * rng.randf_range(1.4, 2.0))
			_build_continuous_branch(st_bark, [p_arm_mid, sec_tip, tert_tip0], [r_base * 0.40, 0.11, 0.01], sides, true, true)
			_add_volumetric_foliage_cards(st_foliage, tert_tip0, rng.randf_range(4.0, 4.6), rng, 2)

			var tert_ang1 = sub_ang + 0.45 + rng.randf_range(-0.1, 0.1)
			var tert_tip1 = sec_tip + Vector3(cos(tert_ang1) * rng.randf_range(1.4, 2.0), rng.randf_range(0.5, 1.2), sin(tert_ang1) * rng.randf_range(1.4, 2.0))
			_build_cylinder_segment(st_bark, sec_tip, tert_tip1, 0.08, 0.01, 4)
			_add_volumetric_foliage_cards(st_foliage, tert_tip1, rng.randf_range(4.0, 4.6), rng, 2)

			_add_volumetric_foliage_cards(st_foliage, sec_tip, rng.randf_range(3.8, 4.4), rng, 2)

	# Ponte de galho cruzando entre as duas metades
	if arm_mids.size() == 2:
		var bridge_mid = (arm_mids[0] + arm_mids[1]) * 0.5 + Vector3(0, rng.randf_range(0.5, 1.5), 0)
		_build_continuous_branch(st_bark, [arm_mids[0], bridge_mid, arm_mids[1]], [0.14, 0.08, 0.14], 4, true, true)
		_add_volumetric_foliage_cards(st_foliage, bridge_mid, rng.randf_range(3.8, 4.4), rng, 2)

	return _finalize_tree_mesh(st_bark, st_foliage, Color(0.22, 0.16, 0.10))


## -----------------------------------------------------------------------------
## ARQUÉTIPO 3: Árvore Antiga / Torta (Old Gnarled Crooked Tree)
## Tronco inclinado/tortuoso, galhos assimétricos e retorcidos, nós e irregularidades
## -----------------------------------------------------------------------------
func _build_thick_gnarled_tree(seed_val: int) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var st_bark = SurfaceTool.new()
	st_bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_foliage = SurfaceTool.new()
	st_foliage.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sides = 6
	var r_base = 0.60

	# Tronco retorcido com forte inclinação contínuo sem cortes
	var p0 = Vector3.ZERO
	var p1 = Vector3(rng.randf_range(0.35, 0.60), 1.8, rng.randf_range(-0.35, -0.15))
	var p2 = Vector3(rng.randf_range(0.60, 0.95), 3.8, rng.randf_range(0.15, 0.40))
	var p3 = Vector3(rng.randf_range(0.30, 0.60), 6.5, rng.randf_range(0.45, 0.75))

	_build_continuous_branch(st_bark, [p0, p1, p2, p3], [r_base, r_base * 0.90, r_base * 0.78, r_base * 0.65], sides, true, false)

	# Galho morto grosso lateral a 3.2m
	var dead_bough = Vector3(rng.randf_range(-0.85, -0.6), rng.randf_range(-0.15, 0.1), rng.randf_range(-0.5, 0.5)).normalized()
	_build_cylinder_segment(st_bark, p2, p2 + dead_bough * 2.6, 0.25, 0.04, 4)

	# 3 Galhos grossos assimétricos a partir de p3 (alcance de 4.5m a 6.2m)
	for i in range(3):
		var ang = float(i) * (TAU / 3.0) + rng.randf_range(-0.25, 0.25)
		var bough_dir = Vector3(cos(ang) * 0.85, rng.randf_range(0.25, 0.55), sin(ang) * 0.85).normalized()
		var bough_mid = p3 + bough_dir * rng.randf_range(3.2, 4.2)
		_build_cylinder_segment(st_bark, p3, bough_mid, r_base * 0.55, 0.24, sides)

		# Sub-galhos espalhando horizontalmente
		for s in range(2):
			var sub_ang = ang + (float(s) - 0.5) * 1.0 + rng.randf_range(-0.2, 0.2)
			var sub_dir = Vector3(cos(sub_ang) * 0.85, rng.randf_range(0.3, 0.6), sin(sub_ang) * 0.85).normalized()
			var tip = bough_mid + sub_dir * rng.randf_range(2.8, 3.8)

			var tert_ang0 = sub_ang - 0.45 + rng.randf_range(-0.1, 0.1)
			var tert_tip0 = tip + Vector3(cos(tert_ang0) * rng.randf_range(1.5, 2.2), rng.randf_range(0.4, 1.0), sin(tert_ang0) * rng.randf_range(1.5, 2.2))
			_build_continuous_branch(st_bark, [bough_mid, tip, tert_tip0], [0.22, 0.09, 0.01], sides, true, true)
			_add_volumetric_foliage_cards(st_foliage, tert_tip0, rng.randf_range(4.2, 4.8), rng, 2)

			var tert_ang1 = sub_ang + 0.45 + rng.randf_range(-0.1, 0.1)
			var tert_tip1 = tip + Vector3(cos(tert_ang1) * rng.randf_range(1.5, 2.2), rng.randf_range(0.4, 1.0), sin(tert_ang1) * rng.randf_range(1.5, 2.2))
			_build_cylinder_segment(st_bark, tip, tert_tip1, 0.08, 0.01, 4)
			_add_volumetric_foliage_cards(st_foliage, tert_tip1, rng.randf_range(4.2, 4.8), rng, 2)

			_add_volumetric_foliage_cards(st_foliage, tip, rng.randf_range(4.0, 4.6), rng, 2)

	return _finalize_tree_mesh(st_bark, st_foliage, Color(0.18, 0.13, 0.08))


## -----------------------------------------------------------------------------
## ARQUÉTIPO 4: Árvore Jovem / Esguia (Young Slender Tree)
## Tronco mais fino, copa mais alta e compacta, servindo de preenchimento
## -----------------------------------------------------------------------------
func _build_young_slender_tree(seed_val: int) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var st_bark = SurfaceTool.new()
	st_bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_foliage = SurfaceTool.new()
	st_foliage.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sides = 6
	var r_base = 0.28

	# Tronco fino e esguio (~10.5m) contínuo sem cortes
	var p0 = Vector3.ZERO
	var p1 = Vector3(rng.randf_range(-0.1, 0.1), 3.0, rng.randf_range(-0.1, 0.1))
	var p2 = Vector3(rng.randf_range(-0.15, 0.15), 6.5, rng.randf_range(-0.15, 0.15))
	var p_top = Vector3(rng.randf_range(-0.15, 0.15), 10.2, rng.randf_range(-0.15, 0.15))

	_build_continuous_branch(st_bark, [p0, p1, p2, p_top], [r_base, r_base * 0.82, r_base * 0.65, 0.09], sides, true, true)

	# 4 Galhos ascendentes formando copa compacta e alta
	for i in range(4):
		var ang = float(i) * (TAU / 4.0) + rng.randf_range(-0.25, 0.25)
		var h_attach = rng.randf_range(7.0, 8.8)
		var attach_pt = p2.lerp(p_top, (h_attach - 6.5) / 3.7)
		var b_reach = rng.randf_range(2.0, 2.8)
		var b_tip = attach_pt + Vector3(cos(ang) * b_reach, rng.randf_range(1.6, 2.5), sin(ang) * b_reach)

		# Raminho terciário contínuo
		var tert_ang = ang + rng.randf_range(-0.5, 0.5)
		var tert_tip = b_tip + Vector3(cos(tert_ang) * 1.2, rng.randf_range(0.6, 1.2), sin(tert_ang) * 1.2)
		_build_continuous_branch(st_bark, [attach_pt, b_tip, tert_tip], [0.13, 0.06, 0.01], 4, true, true)
		_add_volumetric_foliage_cards(st_foliage, b_tip, rng.randf_range(3.4, 4.0), rng, 2)
		_add_volumetric_foliage_cards(st_foliage, tert_tip, rng.randf_range(3.6, 4.2), rng, 2)

	# Copa no ápice
	_add_volumetric_foliage_cards(st_foliage, p_top, rng.randf_range(3.8, 4.4), rng, 3)

	return _finalize_tree_mesh(st_bark, st_foliage, Color(0.26, 0.21, 0.14))


## -----------------------------------------------------------------------------
## ARQUÉTIPO 5: Árvore Alta Multinível (Tall Multi-Tier Dense Tree)
## Tronco robusto com galhos espalhados em diferentes andares verticais
## -----------------------------------------------------------------------------
func _build_tall_multitier_tree(seed_val: int) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var st_bark = SurfaceTool.new()
	st_bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_foliage = SurfaceTool.new()
	st_foliage.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sides = 6
	var r_base = 0.48

	# Coluna central contínua até ~14.2m
	var p0 = Vector3.ZERO
	var p1 = Vector3(rng.randf_range(-0.15, 0.15), 4.2, rng.randf_range(-0.15, 0.15))
	var p2 = Vector3(rng.randf_range(-0.2, 0.2), 8.5, rng.randf_range(-0.2, 0.2))
	var p3 = Vector3(rng.randf_range(-0.2, 0.2), 12.0, rng.randf_range(-0.2, 0.2))
	var p_top = Vector3(rng.randf_range(-0.1, 0.1), 14.2, rng.randf_range(-0.1, 0.1))

	_build_continuous_branch(st_bark, [p0, p1, p2, p3, p_top], [r_base, r_base * 0.85, r_base * 0.70, r_base * 0.50, 0.08], sides, true, true)

	# Andar 1 (Copa baixa a ~5.8m): 3 galhos horizontais
	var tier1_pt = p1.lerp(p2, (5.8 - 4.2) / 4.3)
	for i in range(3):
		var ang = float(i) * (TAU / 3.0) + rng.randf_range(-0.2, 0.2)
		var b_tip = tier1_pt + Vector3(cos(ang) * rng.randf_range(3.0, 3.8), rng.randf_range(0.3, 0.8), sin(ang) * rng.randf_range(3.0, 3.8))
		_build_cylinder_segment(st_bark, tier1_pt, b_tip, 0.22, 0.08, sides)
		_add_volumetric_foliage_cards(st_foliage, b_tip, rng.randf_range(3.8, 4.4), rng, 2)

	# Andar 2 (Copa média a ~9.2m): 3 galhos rotacionados 60°
	var tier2_pt = p2.lerp(p3, (9.2 - 8.5) / 3.5)
	for i in range(3):
		var ang = float(i) * (TAU / 3.0) + (PI / 3.0) + rng.randf_range(-0.2, 0.2)
		var b_mid = tier2_pt + Vector3(cos(ang) * rng.randf_range(3.2, 4.0), rng.randf_range(0.6, 1.2), sin(ang) * rng.randf_range(3.2, 4.0))

		# Ramificações terciárias contínuas
		var tert_ang0 = ang - 0.4
		var tert_tip0 = b_mid + Vector3(cos(tert_ang0) * 1.8, rng.randf_range(0.5, 1.1), sin(tert_ang0) * 1.8)
		_build_continuous_branch(st_bark, [tier2_pt, b_mid, tert_tip0], [0.20, 0.09, 0.01], sides, true, true)
		_add_volumetric_foliage_cards(st_foliage, tert_tip0, rng.randf_range(4.0, 4.6), rng, 2)

		var tert_ang1 = ang + 0.4
		var tert_tip1 = b_mid + Vector3(cos(tert_ang1) * 1.8, rng.randf_range(0.5, 1.1), sin(tert_ang1) * 1.8)
		_build_cylinder_segment(st_bark, b_mid, tert_tip1, 0.08, 0.01, 4)
		_add_volumetric_foliage_cards(st_foliage, tert_tip1, rng.randf_range(4.0, 4.6), rng, 2)

		_add_volumetric_foliage_cards(st_foliage, b_mid, rng.randf_range(3.8, 4.4), rng, 2)

	# Andar 3 (Copa alta a ~12.2m): 4 galhos espalhados
	for i in range(4):
		var ang = float(i) * (TAU / 4.0) + rng.randf_range(-0.25, 0.25)
		var b_tip = p3 + Vector3(cos(ang) * rng.randf_range(2.6, 3.4), rng.randf_range(0.8, 1.5), sin(ang) * rng.randf_range(2.6, 3.4))
		_build_cylinder_segment(st_bark, p3, b_tip, 0.16, 0.07, sides)
		_add_volumetric_foliage_cards(st_foliage, b_tip, rng.randf_range(4.0, 4.6), rng, 2)

	# Ápice
	_add_volumetric_foliage_cards(st_foliage, p_top, rng.randf_range(4.2, 4.8), rng, 3)

	return _finalize_tree_mesh(st_bark, st_foliage, Color(0.20, 0.15, 0.10))


## -----------------------------------------------------------------------------
## ARQUÉTIPO 6: Árvore Seca / Esquelética (Dead Standing Tree)
## Sem folhas (1 superfície), galhos pontiagudos quebrados e casca cinzenta desbotada
## -----------------------------------------------------------------------------
func _build_dead_standing_tree(seed_val: int) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var st_bark = SurfaceTool.new()
	st_bark.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sides = 6
	var r_base = 0.42

	# Tronco seco sinuoso contínuo até o topo esquelético (~11.4m)
	var p0 = Vector3.ZERO
	var p1 = Vector3(rng.randf_range(-0.2, 0.2), 3.0, rng.randf_range(-0.2, 0.2))
	var p2 = Vector3(rng.randf_range(-0.35, 0.35), 6.5, rng.randf_range(-0.35, 0.35))
	var p3 = Vector3(rng.randf_range(-0.25, 0.25), 9.2, rng.randf_range(-0.25, 0.25))
	var p_top = p3 + Vector3(rng.randf_range(-0.2, 0.2), 2.2, rng.randf_range(-0.2, 0.2))

	_build_continuous_branch(st_bark, [p0, p1, p2, p3, p_top], [r_base, r_base * 0.85, r_base * 0.70, r_base * 0.50, 0.005], sides, true, true)

	# Galho quebrado baixo a 3.5m
	var stub_dir = Vector3(rng.randf_range(0.7, 0.9), rng.randf_range(-0.2, 0.1), rng.randf_range(-0.4, 0.4)).normalized()
	_build_cylinder_segment(st_bark, p1 + Vector3(0, 0.5, 0), p1 + Vector3(0, 0.5, 0) + stub_dir * 1.5, 0.16, 0.04, 4)

	# 5 Galhos esqueléticos quebrados
	var b_heights = [5.5, 7.2, 8.5, 9.8, 10.4]
	for idx in range(b_heights.size()):
		var h = b_heights[idx]
		var t_pos = p1.lerp(p3, (h - 3.0) / 6.2) if h <= 9.2 else p3.lerp(p_top, (h - 9.2) / 2.2)
		var ang = float(idx) * 1.4 + rng.randf_range(-0.25, 0.25)
		var b_len = rng.randf_range(2.4, 4.2)
		var b_dir = Vector3(cos(ang) * 0.8, rng.randf_range(0.2, 0.6), sin(ang) * 0.8).normalized()
		var b_tip = t_pos + b_dir * b_len

		_build_cylinder_segment(st_bark, t_pos, b_tip, 0.18, 0.005, 4)

		# Galho secundário quebrado
		if rng.randf() > 0.3:
			var twig_ang = ang + rng.randf_range(0.5, 1.2)
			var twig_dir = Vector3(cos(twig_ang) * 0.7, rng.randf_range(0.2, 0.7), sin(twig_ang) * 0.7).normalized()
			var twig_tip = b_tip.lerp(t_pos, 0.4) + twig_dir * rng.randf_range(1.2, 2.0)
			_build_cylinder_segment(st_bark, b_tip.lerp(t_pos, 0.4), twig_tip, 0.07, 0.005, 4)

	return _finalize_dead_tree_mesh(st_bark, Color(0.38, 0.36, 0.33))


## -----------------------------------------------------------------------------
## ARQUÉTIPO 7: Tronco Quebrado / Partido (Dead Broken Trunk)
## Sem folhas (1 superfície), tronco quebrado no meio (~4.8m) com lascas visíveis e casca cinzenta
## -----------------------------------------------------------------------------
func _build_dead_broken_trunk(seed_val: int) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var st_bark = SurfaceTool.new()
	st_bark.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sides = 6
	var r_base = 0.54

	# Tronco grosso contínuo até a altura da quebra (~4.8m)
	var p0 = Vector3.ZERO
	var p1 = Vector3(rng.randf_range(-0.15, 0.15), 2.4, rng.randf_range(-0.15, 0.15))
	var p_snap = Vector3(rng.randf_range(-0.25, 0.25), 4.8, rng.randf_range(-0.25, 0.25))

	_build_continuous_branch(st_bark, [p0, p1, p_snap], [r_base, r_base * 0.88, r_base * 0.78], sides, true, true)

	# 2 Galhos quebrados remanescentes na lateral
	var stub1_dir = Vector3(rng.randf_range(-0.8, -0.6), rng.randf_range(-0.1, 0.2), rng.randf_range(0.4, 0.7)).normalized()
	_build_cylinder_segment(st_bark, p1, p1 + stub1_dir * 1.5, 0.18, 0.05, 4)

	var stub2_dir = Vector3(rng.randf_range(0.5, 0.8), rng.randf_range(0.1, 0.3), rng.randf_range(-0.7, -0.4)).normalized()
	_build_cylinder_segment(st_bark, p1 + Vector3(0, 1.2, 0), p1 + Vector3(0, 1.2, 0) + stub2_dir * 1.2, 0.14, 0.04, 4)

	# Lascas pontiagudas (wood splinters) projetando-se para cima da quebra
	var r_snap = r_base * 0.78
	var num_splinters = 7
	for i in range(num_splinters):
		var sp_ang = float(i) * (TAU / float(num_splinters)) + rng.randf_range(-0.2, 0.2)
		var rim_dist = r_snap * rng.randf_range(0.55, 0.95)
		var rim_pos = p_snap + Vector3(cos(sp_ang) * rim_dist, 0, sin(sp_ang) * rim_dist)

		var sp_height = rng.randf_range(1.4, 2.0) if i == 0 else rng.randf_range(0.5, 1.2)
		var sp_lean = Vector3(cos(sp_ang) * rng.randf_range(0.05, 0.25), 1.0, sin(sp_ang) * rng.randf_range(0.05, 0.25)).normalized()
		var sp_tip = rim_pos + sp_lean * sp_height
		var sp_base_r = rng.randf_range(0.06, 0.12)

		# Lasca piramidal afunilando até o ápice pontiagudo
		_build_cylinder_segment(st_bark, rim_pos, sp_tip, sp_base_r, 0.002, 4)

	# Lascas centrais internas
	for c in range(2):
		var c_pos = p_snap + Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
		var c_tip = c_pos + Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(0.7, 1.4), rng.randf_range(-0.1, 0.1))
		_build_cylinder_segment(st_bark, c_pos, c_tip, 0.08, 0.002, 4)

	return _finalize_dead_tree_mesh(st_bark, Color(0.36, 0.34, 0.31))


## Constrói uma cadeia/galho contínuo de segmentos unidos sem fendas, furos ou quinas cortadas
func _build_continuous_branch(
	st: SurfaceTool,
	points: Array[Vector3],
	radii: Array[float],
	sides: int = 6,
	close_start: bool = true,
	close_end: bool = true
) -> void:
	var n_pts = points.size()
	if n_pts < 2:
		return

	# 1. Calcular tangentes/normais dos anéis em cada nó
	var dirs: Array[Vector3] = []
	for i in range(n_pts - 1):
		var d = points[i + 1] - points[i]
		var len_sq = d.length_squared()
		if len_sq > 0.000001:
			dirs.append(d / sqrt(len_sq))
		else:
			dirs.append(Vector3.UP)

	# Vetor normal do plano de cada nó
	var ring_normals: Array[Vector3] = []
	var miter_scales: Array[float] = []

	# Nó inicial
	ring_normals.append(dirs[0])
	miter_scales.append(1.0)

	# Nós intermediários (onde o tronco curva e forma a quina)
	for i in range(1, n_pts - 1):
		var d_in = dirs[i - 1]
		var d_out = dirs[i]
		var joint_dir = (d_in + d_out).normalized()
		if joint_dir.length_squared() < 0.0001:
			joint_dir = d_out
		ring_normals.append(joint_dir)

		# Miter scale para manter o diâmetro do tronco constante na curva sem encolher nem inflar
		var dot_val = d_in.dot(joint_dir)
		var m_scale = 1.0
		if dot_val > 0.001:
			m_scale = clamp(1.0 / dot_val, 1.0, 1.35)
		miter_scales.append(m_scale)

	# Nó final
	ring_normals.append(dirs[n_pts - 2])
	miter_scales.append(1.0)

	# 2. Propagação de coordenadas (u, v) sem torção (Parallel Transport Frame)
	var u_axes: Array[Vector3] = []
	var v_axes: Array[Vector3] = []

	var init_up = Vector3.UP if abs(ring_normals[0].dot(Vector3.UP)) < 0.85 else Vector3.RIGHT
	var u0 = ring_normals[0].cross(init_up).normalized()
	var v0 = ring_normals[0].cross(u0).normalized()
	u_axes.append(u0)
	v_axes.append(v0)

	for i in range(1, n_pts):
		var norm = ring_normals[i]
		var prev_u = u_axes[i - 1]
		var proj_u = prev_u - norm * norm.dot(prev_u)
		if proj_u.length_squared() > 0.0001:
			u0 = proj_u.normalized()
		else:
			var alt_up = Vector3.UP if abs(norm.dot(Vector3.UP)) < 0.85 else Vector3.RIGHT
			u0 = norm.cross(alt_up).normalized()
		v0 = norm.cross(u0).normalized()
		u_axes.append(u0)
		v_axes.append(v0)

	# 3. Gerar vértices dos anéis (compartilhados entre segmentos adjacentes)
	var rings: Array = []
	for i in range(n_pts):
		var ring_verts: Array[Vector3] = []
		var r = radii[i] * miter_scales[i]
		var pt = points[i]
		var u = u_axes[i]
		var v = v_axes[i]

		for j in range(sides):
			var angle = float(j) * TAU / float(sides)
			var offset = (u * cos(angle) + v * sin(angle)) * r
			ring_verts.append(pt + offset)
		rings.append(ring_verts)

	# 4. Construir quads/triângulos contínuos entre anel i e anel i+1
	var current_v_uv = 0.0
	for i in range(n_pts - 1):
		var r_curr = rings[i]
		var r_next = rings[i + 1]
		var seg_len = points[i].distance_to(points[i + 1])
		var next_v_uv = current_v_uv + seg_len * 0.5

		if radii[i + 1] < 0.01:
			# Ápice cônico fechado na ponta
			var apex = points[i + 1]
			for j in range(sides):
				var j_next = (j + 1) % sides
				var p0 = r_curr[j]
				var p1 = r_curr[j_next]
				var norm = (p1 - p0).cross(apex - p0).normalized()
				st.set_normal(norm)
				st.set_uv(Vector2(float(j) / float(sides), current_v_uv))
				st.add_vertex(p0)
				st.set_normal(norm)
				st.set_uv(Vector2(float(j + 1) / float(sides), current_v_uv))
				st.add_vertex(p1)
				st.set_normal(norm)
				st.set_uv(Vector2((float(j) + 0.5) / float(sides), next_v_uv))
				st.add_vertex(apex)
		else:
			for j in range(sides):
				var j_next = (j + 1) % sides
				var p0 = r_curr[j]
				var p1 = r_curr[j_next]
				var p2 = r_next[j_next]
				var p3 = r_next[j]

				var u_left = float(j) / float(sides)
				var u_right = float(j + 1) / float(sides)

				var n1 = (p1 - p0).cross(p2 - p0).normalized()
				st.set_normal(n1)
				st.set_uv(Vector2(u_left, current_v_uv))
				st.add_vertex(p0)
				st.set_normal(n1)
				st.set_uv(Vector2(u_right, current_v_uv))
				st.add_vertex(p1)
				st.set_normal(n1)
				st.set_uv(Vector2(u_right, next_v_uv))
				st.add_vertex(p2)

				var n2 = (p2 - p0).cross(p3 - p0).normalized()
				st.set_normal(n2)
				st.set_uv(Vector2(u_left, current_v_uv))
				st.add_vertex(p0)
				st.set_normal(n2)
				st.set_uv(Vector2(u_right, next_v_uv))
				st.add_vertex(p2)
				st.set_normal(n2)
				st.set_uv(Vector2(u_left, next_v_uv))
				st.add_vertex(p3)

		current_v_uv = next_v_uv

	# 5. Tampas (Caps) para vedar pontas abertas
	if close_start and radii[0] > 0.005:
		var center_start = points[0]
		var cap_norm = -ring_normals[0]
		var r0_ring = rings[0]
		for j in range(sides):
			var j_next = (j + 1) % sides
			st.set_normal(cap_norm)
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(center_start)
			st.set_normal(cap_norm)
			st.set_uv(Vector2(0.5 + 0.5 * cos(float(j_next) * TAU / float(sides)), 0.5 + 0.5 * sin(float(j_next) * TAU / float(sides))))
			st.add_vertex(r0_ring[j_next])
			st.set_normal(cap_norm)
			st.set_uv(Vector2(0.5 + 0.5 * cos(float(j) * TAU / float(sides)), 0.5 + 0.5 * sin(float(j) * TAU / float(sides))))
			st.add_vertex(r0_ring[j])

	if close_end and radii[n_pts - 1] >= 0.01:
		var center_end = points[n_pts - 1]
		var cap_norm = ring_normals[n_pts - 1]
		var rend_ring = rings[n_pts - 1]
		for j in range(sides):
			var j_next = (j + 1) % sides
			st.set_normal(cap_norm)
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(center_end)
			st.set_normal(cap_norm)
			st.set_uv(Vector2(0.5 + 0.5 * cos(float(j) * TAU / float(sides)), 0.5 + 0.5 * sin(float(j) * TAU / float(sides))))
			st.add_vertex(rend_ring[j])
			st.set_normal(cap_norm)
			st.set_uv(Vector2(0.5 + 0.5 * cos(float(j_next) * TAU / float(sides)), 0.5 + 0.5 * sin(float(j_next) * TAU / float(sides))))
			st.add_vertex(rend_ring[j_next])


## Constrói segmento cilíndrico selado e seguro
func _build_cylinder_segment(st: SurfaceTool, start_pt: Vector3, end_pt: Vector3, r_start: float, r_end: float, sides: int = 6) -> void:
	_build_continuous_branch(st, [start_pt, end_pt], [r_start, r_end], sides, true, true)


## Adiciona cluster volumétrico de folhas 2D com rotações 3D completas (Roll, Pitch, Yaw)
## Inclui planos inclinados para baixo e para cima para formar volume esférico visto de todos os ângulos
func _add_volumetric_foliage_cards(st: SurfaceTool, center: Vector3, size: float, rng: RandomNumberGenerator, count: int = 5) -> void:
	for c in range(count):
		var pitch: float
		var roll: float
		var yaw = rng.randf_range(0.0, TAU)

		# Distribui orientações tridimensionais ricas
		match c % 5:
			0:
				# Inclinado para cima (captura luz do sol)
				pitch = rng.randf_range(0.35, 0.65)
				roll = rng.randf_range(-0.35, 0.35)
			1:
				# Inclinado para baixo (visível para o jogador olhando de baixo para o dossel)
				pitch = rng.randf_range(-0.65, -0.35)
				roll = rng.randf_range(-0.35, 0.35)
			2:
				# Praticamente vertical
				pitch = rng.randf_range(-0.15, 0.15)
				roll = rng.randf_range(-0.4, 0.4)
			3:
				# Oblíquo acentuado
				pitch = rng.randf_range(-0.5, 0.5)
				roll = rng.randf_range(0.5, 0.9)
			4:
				# Oblíquo oposto
				pitch = rng.randf_range(-0.4, 0.4)
				roll = rng.randf_range(-0.9, -0.5)
			_:
				pitch = rng.randf_range(-0.5, 0.5)
				roll = rng.randf_range(-0.5, 0.5)

		# Pequeno deslocamento espacial para volume esferoide
		var offset = Vector3(
			rng.randf_range(-0.35, 0.35),
			rng.randf_range(-0.25, 0.25),
			rng.randf_range(-0.35, 0.35)
		) * size
		var card_pos = center + offset

		var card_w = size * rng.randf_range(0.85, 1.15)
		var card_h = size * rng.randf_range(0.85, 1.15)

		var basis = Basis.from_euler(Vector3(pitch, yaw, roll))
		var right = basis.x * (card_w * 0.5)
		var up = basis.y * (card_h * 0.5)

		var p0 = card_pos - right - up
		var p1 = card_pos + right - up
		var p2 = card_pos + right + up
		var p3 = card_pos - right + up

		var n = (p1 - p0).cross(p2 - p0).normalized()

		# Tri 1
		st.set_normal(n)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(p0)
		st.set_normal(n)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(p1)
		st.set_normal(n)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(p2)

		# Tri 2
		st.set_normal(n)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(p0)
		st.set_normal(n)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(p2)
		st.set_normal(n)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(p3)


## Combina casca e folhagem em malha com 2 superfícies (Alpha Scissor + Per-Vertex Shading)
func _finalize_tree_mesh(st_bark: SurfaceTool, st_foliage: SurfaceTool, bark_col: Color) -> ArrayMesh:
	var bark_mat = StandardMaterial3D.new()
	bark_mat.albedo_color = bark_col
	bark_mat.roughness = 1.0
	bark_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	bark_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bark_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	bark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX

	var foliage_mat = StandardMaterial3D.new()
	var tex = load("res://assets/textures/branch_leaves.png")
	if tex == null:
		tex = load("res://assets/textures/canopy_leaves.png")
	foliage_mat.albedo_texture = tex
	foliage_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	foliage_mat.alpha_scissor_threshold = 0.5
	foliage_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	foliage_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	foliage_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	foliage_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	foliage_mat.roughness = 1.0
	foliage_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	foliage_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT

	st_bark.set_material(bark_mat)
	var mesh = st_bark.commit()

	st_foliage.set_material(foliage_mat)
	mesh = st_foliage.commit(mesh)

	return mesh


## Finaliza malha de árvore morta (1 superfície única de casca cinzenta/desbotada, 0 superfícies de folhas)
func _finalize_dead_tree_mesh(st_bark: SurfaceTool, bark_col: Color) -> ArrayMesh:
	var bark_mat = StandardMaterial3D.new()
	bark_mat.albedo_color = bark_col
	bark_mat.roughness = 1.0
	bark_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	bark_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bark_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	bark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX

	st_bark.set_material(bark_mat)
	return st_bark.commit()
