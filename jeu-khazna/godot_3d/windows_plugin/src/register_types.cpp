#include "godot_agora_win.h"

#include <gdextension_interface.h>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

static GodotAgoraWin *instance = nullptr;

void init_agora(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
	ClassDB::register_class<GodotAgoraWin>();
	instance = memnew(GodotAgoraWin);
	// نفس اسم إضافة أندرويد: voice.gd يجدها بـ Engine.has_singleton("GodotAgora")
	Engine::get_singleton()->register_singleton("GodotAgora", instance);
}

void uninit_agora(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
	Engine::get_singleton()->unregister_singleton("GodotAgora");
	if (instance != nullptr) {
		memdelete(instance);
		instance = nullptr;
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT godot_agora_win_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(init_agora);
	init_obj.register_terminator(uninit_agora);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
