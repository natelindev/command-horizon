extends Node

func _ready():
    _run.call_deferred()

func _run():
    while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != "res://source/main-menu/Main.tscn":
        await get_tree().process_frame
    for _index in 120:
        await get_tree().process_frame
    print("Diagnostic ordinary menu ready: graceful Globals.quit_game")
    await get_node("/root/Globals").quit_game()
