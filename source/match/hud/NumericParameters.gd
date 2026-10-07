extends VBoxContainer

signal changed(values)

var values = []


func set_values(data):
	values = data.duplicate(true)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for index in values.size():
		var item = values[index]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		add_child(row)
		var title = Label.new()
		title.text = item.label
		title.tooltip_text = item.name
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var field = SpinBox.new()
		field.custom_minimum_size.x = 130
		field.min_value = item.min
		field.max_value = item.max
		field.step = 0
		field.custom_arrow_step = item.step
		field.value = item.value
		field.value_changed.connect(_change.bind(index))
		row.add_child(field)


func _change(value, index):
	values[index].value = value
	changed.emit(values.duplicate(true))
