extends CheckBox

@onready var line_edit: LineEdit = $"../LineEdit"


func _on_toggled(toggled_on: bool) -> void:
	line_edit.visible = toggled_on
