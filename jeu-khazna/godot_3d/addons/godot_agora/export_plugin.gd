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


# رابط khazna3d://open و khazna3d://join?code=1234 (من تطبيق الخزنة الأصلي) داخل نشاط اللعبة الرئيسي
func _get_android_manifest_activity_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
	return """
		<intent-filter>
			<action android:name="android.intent.action.VIEW" />
			<category android:name="android.intent.category.DEFAULT" />
			<category android:name="android.intent.category.BROWSABLE" />
			<data android:scheme="khazna3d" />
		</intent-filter>
"""
