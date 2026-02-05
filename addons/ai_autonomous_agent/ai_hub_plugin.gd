@tool
class_name AIHubPlugin
extends EditorPlugin

const AIAssistantHub = preload("res://addons/ai_autonomous_agent/ai_assistant_hub.gd")
const LLMConfigManager = preload("res://addons/ai_autonomous_agent/llm_config_manager.gd")
const LLMInterface = preload("res://addons/ai_autonomous_agent/llm_apis/llm_interface.gd")
const LLMProviderResource = preload("res://addons/ai_autonomous_agent/llm_providers/llm_provider_resource.gd")
const GeminiAPI = preload("res://addons/ai_autonomous_agent/llm_apis/gemini_api.gd")
const OpenRouterAPI = preload("res://addons/ai_autonomous_agent/llm_apis/openrouter_api.gd")
const OpenWebUIAPI = preload("res://addons/ai_autonomous_agent/llm_apis/openwebui_api.gd")

enum ThinkingTargets {Output, Chat, Discard}
const PREF_REMOVE_THINK := "plugins/ai_assistant_hub/preferences/thinking_target"
const PREF_SCROLL_BOTTOM := "plugins/ai_assistant_hub/preferences/always_scroll_to_bottom"
const PREF_SKIP_GREETING := "plugins/ai_assistant_hub/preferences/skip_greeting"

const CONFIG_LLM_API := "plugins/ai_assistant_hub/llm_api"

# Configuration deprecated in version 1.6.0
const DEPRECATED_CONFIG_OPENROUTER_API_KEY := "plugins/ai_assistant_hub/openrouter_api_key"
const DEPRECATED_CONFIG_GEMINI_API_KEY := "plugins/ai_assistant_hub/gemini_api_key"
const DEPRECATED_CONFIG_OPENWEBUI_API_KEY := "plugins/ai_assistant_hub/openwebui_api_key"

var _hub_dock: AIAssistantHub
var _settings_window: Window
var _use_internal_hub_dock: bool = true

func _enter_tree() -> void:
	initialize_project_settings()
	if _use_internal_hub_dock:
		_hub_dock = load("res://addons/ai_autonomous_agent/ai_assistant_hub.tscn").instantiate()
		_hub_dock.initialize(self)
		_hub_dock.set_meta("_phoenix_focus_dock", true)
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _hub_dock)
	add_tool_menu_item("AI Assistant Settings", Callable(self, "_open_settings_window"))


func initialize_project_settings() -> void:
	# Version 1.6.0 cleanup - Migrate base URL from global setting to per LLM setting
	var api_id: String = ProjectSettings.get_setting(AIHubPlugin.CONFIG_LLM_API, "")
	if not api_id.is_empty():
		var config_base_url = LLMConfigManager.new(api_id)
		config_base_url.migrate_deprecated_1_5_0_base_url()
	
	# Version 1.6.0 cleanup - delete API key files and project settings
	var config_gemini = LLMConfigManager.new("gemini_api")
	var dummy := LLMProviderResource.new()
	dummy.api_id = "dummy"
	config_gemini.migrate_deprecated_1_5_0_api_key(
		(GeminiAPI.new(dummy)).get_deprecated_api_key(),
		GeminiAPI.DEPRECATED_API_KEY_SETTING,
		GeminiAPI.DEPRECATED_API_KEY_FILE)
	var config_openrouter = LLMConfigManager.new("openrouter_api")
	config_openrouter.migrate_deprecated_1_5_0_api_key(
		OpenRouterAPI.new(dummy).get_deprecated_api_key(),
		OpenRouterAPI.DEPRECATED_API_KEY_SETTING,
		OpenRouterAPI.DEPRECATED_API_KEY_FILE)
	var config_openwebui = LLMConfigManager.new("openwebui_api")
	config_openwebui.migrate_deprecated_1_5_0_api_key(
		OpenWebUIAPI.new(dummy).get_deprecated_api_key(),
		OpenWebUIAPI.DEPRECATED_API_KEY_SETTING)
	
	if ProjectSettings.get_setting(CONFIG_LLM_API, "").is_empty():
		# In the future we can consider moving this back to simply:
		# ProjectSettings.set_setting(CONFIG_LLM_API, "ollama_api")
		# the code below handles migrating the config from 1.2.0 to 1.3.0
		var old_path := "ai_assistant_hub/llm_api"
		if ProjectSettings.has_setting(old_path):
			ProjectSettings.set_setting(CONFIG_LLM_API, ProjectSettings.get_setting(old_path))
			ProjectSettings.set_setting(old_path, null)
			ProjectSettings.save()
		else:
			ProjectSettings.set_setting(CONFIG_LLM_API, "ollama_api")
	
	if not ProjectSettings.has_setting(PREF_REMOVE_THINK):
		ProjectSettings.set_setting(PREF_REMOVE_THINK, ThinkingTargets.Output)
		ProjectSettings.save()
	
	if not ProjectSettings.has_setting(PREF_SKIP_GREETING):
		ProjectSettings.set_setting(PREF_SKIP_GREETING, false)
		ProjectSettings.save()
	
	var property_info = {
		"name": PREF_REMOVE_THINK,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Output,Chat,Discard"
	}
	ProjectSettings.add_property_info(property_info)
	
	if not ProjectSettings.has_setting(PREF_SCROLL_BOTTOM):
		ProjectSettings.set_setting(PREF_SCROLL_BOTTOM, false)
		ProjectSettings.save()


func _exit_tree() -> void:
	if _use_internal_hub_dock and _hub_dock != null:
		remove_control_from_docks(_hub_dock)
	remove_tool_menu_item("AI Assistant Settings")
	if _hub_dock != null:
		_hub_dock.queue_free()
	if _settings_window != null:
		_settings_window.queue_free()


## Helper function: Add project setting
func _add_project_setting(name: String, default_value, type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> void:
	if ProjectSettings.has_setting(name):
		return
	
	var property_info := {
		"name": name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string
	}
	
	ProjectSettings.set_setting(name, default_value)
	ProjectSettings.add_property_info(property_info)
	ProjectSettings.set_initial_value(name, default_value)


## Load the API dinamically based on the script name given in project setting: ai_assistant_hub/llm_api
## By default this is equivalent to: return OllamaAPI.new()
func new_llm(llm_provider: LLMProviderResource) -> LLMInterface:
	if llm_provider == null:
		push_error("No LLM provider has been selected.")
		return null
	if llm_provider.api_id.is_empty():
		push_error("Provider %s has no API ID." % llm_provider.api_id)
		return null
	var script_path = "res://addons/ai_autonomous_agent/llm_apis/%s.gd" % llm_provider.api_id
	var script = load(script_path)
	if script == null:
		push_error("Failed to load LLM provider script: %s" % script_path)
		return null
	var instance: LLMInterface = script.new(llm_provider)
	if instance == null:
		push_error("Failed to instantiate the LLM provider from script: %s" % script_path)
		return null # Add this line to ensure a value is always returned
	return instance


func get_current_llm_provider() -> LLMProviderResource:
	return _hub_dock.get_selected_llm_resource()


func _open_settings_window() -> void:
	_ensure_settings_window()
	call_deferred("_deferred_open_settings_window")


func open_settings_window() -> void:
	_open_settings_window()


func _on_settings_changed() -> void:
	if _hub_dock != null:
		_hub_dock.refresh_settings()


func _ensure_settings_window() -> void:
	if _settings_window != null:
		return
	_settings_window = load("res://addons/ai_autonomous_agent/ai_settings_window.tscn").instantiate()
	_settings_window.initialize(self)
	_settings_window.settings_changed.connect(_on_settings_changed)
	EditorInterface.get_base_control().call_deferred("add_child", _settings_window)


func _deferred_open_settings_window() -> void:
	if _settings_window != null:
		_settings_window.open_window()


func set_use_internal_hub_dock(enabled: bool) -> void:
	_use_internal_hub_dock = enabled


func set_external_hub_dock(hub: AIAssistantHub) -> void:
	_hub_dock = hub

