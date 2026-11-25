@tool
extends EditorExportPlugin
# يضيف مكتبة Agora (AAR مبنيّة في GitHub) إلى تطبيق أندرويد عند التصدير.


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	return PackedStringArray(["godot_agora/bin/GodotAgora.aar"])


func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	return PackedStringArray(["io.agora.rtc:voice-sdk:4.3.2"])


func _get_name() -> String:
	return "GodotAgora"
