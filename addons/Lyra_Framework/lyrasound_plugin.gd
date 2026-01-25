# res://addons/lyrasound/lyrasound_plugin.gd
@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("LyraEmitter", "Node3D", preload("lyra_emitter.gd"), preload("emitter_icon.png"))

func _exit_tree():
	remove_custom_type("LyraEmitter")
