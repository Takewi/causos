@tool
extends SceneTree

func _init():
	print("Compiling translations from CSV...")
	var file = FileAccess.open("res://localization/translations.csv", FileAccess.READ)
	if not file:
		printerr("Failed to open CSV file")
		quit(1)
		return
	
	var header = file.get_csv_line()
	if header.size() < 2:
		printerr("Invalid CSV header")
		quit(1)
		return
	
	# header[0] is "keys", header[1..n] are locales like pt_BR, en, es
	var translations: Dictionary = {}
	for i in range(1, header.size()):
		var loc = header[i].strip_edges()
		var tr_res = Translation.new()
		tr_res.locale = loc
		translations[loc] = tr_res
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 2:
			continue
		var key = line[0].strip_edges()
		if key.is_empty():
			continue
		for i in range(1, min(line.size(), header.size())):
			var loc = header[i].strip_edges()
			var msg = line[i]
			translations[loc].add_message(key, msg)
	
	file.close()
	
	for loc in translations:
		var path = "res://localization/translations.%s.translation" % loc
		var err = ResourceSaver.save(translations[loc], path)
		print("Saved %s -> %s (err: %s, message count: %d)" % [loc, path, err, translations[loc].get_message_list().size()])
	
	quit(0)
