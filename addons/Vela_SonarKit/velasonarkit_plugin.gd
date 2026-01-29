@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("VelaEmitter", "Node3D", preload("res://addons/Vela_SonarKit/vela_emitter.gd"), preload("res://addons/Vela_SonarKit/emitter_icon.png"))

func _exit_tree():
	remove_custom_type("VelaEmitter")
