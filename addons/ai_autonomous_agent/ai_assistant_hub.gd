@tool
class_name AIAssistantHub
extends Control

const NEW_AI_ASSISTANT_BUTTON = preload("res://addons/ai_autonomous_agent/new_ai_assistant_button.tscn")
const NEW_AI_ASSISTANT_TYPE_WINDOW = preload("res://addons/ai_autonomous_agent/new_ai_assistant_type_window.tscn")
const AI_CHAT = preload("res://addons/ai_autonomous_agent/ai_chat.tscn")

@onready var models_http_request: HTTPRequest = %ModelsHTTPRequest
@onready var models_list: ItemList = %ModelsList
@onready var models_list_error: Label = %ModelsListError
@onready var no_assistants_guide: Label = %NoAssistantsGuide
@onready var assistant_types_container: HFlowContainer = %AssistantTypesContainer
@onready var tab_container: TabContainer = %TabContainer
@onready var new_assistant_type_button: Button = %NewAssistantTypeButton
@onready var settings_hint: Label = %SettingsHint
@onready var open_settings_button: Button = %OpenSettingsButton


var _plugin: AIHubPlugin
var _tab_bar: TabBar
var _model_names: Array[String] = []
var _models_llm: LLMInterface
var _current_api_id: String
var _current_llm_provider: LLMProviderResource


func _tab_changed(tab_index: int) -> void:
	var chat = tab_container.get_current_tab_control()
	if chat is AIChat:
		if chat.save_check_button.button_pressed:
			_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
		else:
			_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY
	else:
		_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER


func _on_chat_save_changed(chat: AIChat, save_on: bool) -> void:
	if tab_container.get_current_tab_control() == chat:
		if save_on:
			_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
		else:
			_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY


func _close_tab(tab_index: int) -> void:
	var chat = tab_container.get_tab_control(tab_index)
	chat.queue_free()


func initialize(plugin: AIHubPlugin) -> void:
	_plugin = plugin
	await ready
	settings_hint.text = "Configure LLM provider in Tools → AI Assistant Settings."
	open_settings_button.pressed.connect(_on_open_settings_pressed)
	_reload_llm_from_settings()
	_on_assistants_refresh_btn_pressed() # Load assistant buttons
	
	_tab_bar = tab_container.get_tab_bar()
	_tab_bar.tab_changed.connect(_tab_changed)
	_tab_bar.tab_close_pressed.connect(_close_tab)
	
	_load_saved_chats()

func _on_refresh_models_btn_pressed() -> void:
	if _current_llm_provider == null or _models_llm == null:
		_set_models_error("Configure the LLM provider in Tools → AI Assistant Settings.")
		return
	var base_url := _get_base_url_for_provider(_current_llm_provider)
	if base_url.is_empty():
		_set_models_error("Configure the Server URL in AI Assistant Settings to load available models.")
		return
	models_list.deselect_all()
	models_list.visible = false
	models_list_error.visible = false
	_models_llm.load_llm_parameters()
	_models_llm.send_get_models_request(models_http_request)


func _on_models_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	models_list_error.visible = false
	models_list.visible = false
	if result == 0:
		if _models_llm == null:
			_set_models_error("LLM provider not configured.")
			return
		var models_returned: Array = _models_llm.read_models_response(body)
		if models_returned.size() == 0:
			models_list_error.text = "No models found. Download at least one model and try again."
			models_list_error.visible = true
		else:
			if models_returned[0] == LLMInterface.INVALID_RESPONSE:
				models_list_error.text = "Error while trying to get the models list. Response: %s" % _models_llm.get_full_response(body)
				models_list_error.visible = true
			else:
				models_list.clear()
				models_list.visible = true
				_model_names = models_returned
				for model in _model_names:
					models_list.add_item(model)
	else:
		push_error("HTTP response: Result: %s, Response Code: %d, Headers: %s, Body: %s" % [result, response_code, headers, body])
		models_list_error.text = "Something went wrong querying for models, is the Server URL correct?"
		models_list_error.visible = true


func _on_assistants_refresh_btn_pressed() -> void:
	var assistants_path = "%s/assistants" % self.scene_file_path.get_base_dir()
	var files = _get_all_resources(assistants_path)
	var found := false
	
	for child in assistant_types_container.get_children():
		if child != no_assistants_guide:
			assistant_types_container.remove_child(child)
	
	for assistant_file in files:
		var assistant = load(assistant_file)
		if assistant is AIAssistantResource:
			found = true
			var new_bot_btn: NewAIAssistantButton = NEW_AI_ASSISTANT_BUTTON.instantiate()
			new_bot_btn.initialize(_plugin, assistant)
			new_bot_btn.chat_created.connect(_on_new_bot_btn_chat_created)
			assistant_types_container.call_deferred("add_child", new_bot_btn)
			var bot_menu: PopupMenu = PopupMenu.new()
			bot_menu.add_item("Edit", 0)
			bot_menu.add_item("Delete", 1)
			new_bot_btn.call_deferred("add_child", bot_menu)
			var menu_callable = Callable(self, "_on_assistant_button_menu_select").bind(assistant_file)
			bot_menu.id_pressed.connect(menu_callable)
			var button_callable = Callable(self, "_on_button_gui_input").bind(bot_menu)
			new_bot_btn.gui_input.connect(button_callable)
	
	if not found:
		no_assistants_guide.text = "Create an agent by selecting a model and clicking \"New agent\"."
		no_assistants_guide.visible = true
		assistant_types_container.visible = false
	else:
		no_assistants_guide.visible = false
		assistant_types_container.visible = true


func _on_button_gui_input(event, delete_menu: PopupMenu):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		delete_menu.position = DisplayServer.mouse_get_position()
		delete_menu.show()


func _on_assistant_button_menu_select(id: int, assistant_file: String) -> void:
	match id:
		0: # Edit
			var res = ResourceLoader.load(assistant_file)
			EditorInterface.edit_resource(res)
		1: # Delete
			DirAccess.remove_absolute(assistant_file)
			_on_assistants_refresh_btn_pressed()
			EditorInterface.get_resource_filesystem().scan()


func _on_new_bot_btn_chat_created(chat: AIChat) -> void:
	tab_container.call_deferred("add_child", chat)
	call_deferred("_deferred_setup_chat_tab", chat)


func get_selected_llm_resource() -> LLMProviderResource:
	return _current_llm_provider


func _on_new_assistant_type_button_pressed() -> void:
	if _current_llm_provider == null:
		push_error("No LLM provider configured. Configure it in AI Assistant Settings.")
		return
	if models_list.is_anything_selected():
		var new_assistant_type_window: NewAIAssistantTypeWindow = NEW_AI_ASSISTANT_TYPE_WINDOW.instantiate()
		var model_name: String = models_list.get_item_text(models_list.get_selected_items()[0])
		var assistants_path = "%s/assistants" % self.scene_file_path.get_base_dir()
		new_assistant_type_window.initialize(_current_llm_provider, model_name, assistants_path)
		new_assistant_type_window.assistant_type_created.connect(_on_assistants_refresh_btn_pressed)
		call_deferred("_deferred_open_new_assistant_window", new_assistant_type_window)
	else:
		new_assistant_type_button.disabled = true


func _on_models_list_item_selected(index: int) -> void:
	new_assistant_type_button.disabled = false


func _on_models_list_empty_clicked(at_position: Vector2, mouse_button_index: int) -> void:
	models_list.deselect_all()
	new_assistant_type_button.disabled = true


func _load_saved_chats() -> void:
	var dir = DirAccess.open(AIChat.SAVE_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while not file_name.is_empty():
			if file_name.ends_with(".cfg"):
				var file_path = "%s/%s" % [AIChat.SAVE_PATH, file_name]
				_load_chat(file_path)
			file_name = dir.get_next()
	tab_container.current_tab = 0


func _load_chat(file_path: String) -> void:
	var chat = AI_CHAT.instantiate()
	chat.initialize_from_file(_plugin, file_path)
	_on_new_bot_btn_chat_created(chat)


func _on_support_btn_pressed() -> void:
	OS.shell_open("https://github.com/FlamxGames/godot-ai-assistant-hub/blob/main/support.md")


func _on_open_settings_pressed() -> void:
	if _plugin:
		_plugin.open_settings_window()


func _deferred_setup_chat_tab(chat: AIChat) -> void:
	if not is_instance_valid(chat):
		return
	tab_container.set_tab_icon(tab_container.get_child_count() - 1, chat.get_assistant_settings().type_icon)
	tab_container.current_tab = chat.get_index()
	chat.save_changed.connect(_on_chat_save_changed)


func _deferred_open_new_assistant_window(window: NewAIAssistantTypeWindow) -> void:
	if not is_instance_valid(window):
		return
	add_child(window)
	window.popup()


func refresh_settings() -> void:
	_reload_llm_from_settings()


func _reload_llm_from_settings() -> void:
	_current_api_id = ProjectSettings.get_setting(AIHubPlugin.CONFIG_LLM_API, "")
	_current_llm_provider = _find_provider_by_api_id(_current_api_id)
	if _current_llm_provider == null:
		_models_llm = null
		_set_models_error("Configure the LLM provider in Tools → AI Assistant Settings.")
		return
	var new_llm: LLMInterface = _plugin.new_llm(_current_llm_provider)
	if new_llm == null:
		_models_llm = null
		_set_models_error("Failed to load LLM provider. Check AI Assistant Settings.")
		return
	_models_llm = new_llm
	_set_models_error("Click refresh to load models.")


func _find_provider_by_api_id(api_id: String) -> LLMProviderResource:
	var files := _get_all_resources("%s/llm_providers" % self.scene_file_path.get_base_dir())
	for provider_file in files:
		var provider = load(provider_file)
		if provider is LLMProviderResource and provider.api_id == api_id:
			return provider
	return null


func _get_base_url_for_provider(provider: LLMProviderResource) -> String:
	if provider == null:
		return ""
	if not provider.fix_url.is_empty():
		return provider.fix_url
	var config = LLMConfigManager.new(provider.api_id)
	return config.load_url()


func _set_models_error(text: String) -> void:
	models_list_error.text = text
	models_list_error.visible = true
	models_list.visible = false


func _get_all_resources(path: String) -> Array[String]:
	var file_paths: Array[String] = []
	var dir = DirAccess.open(path)
	if dir == null:
		return file_paths
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".tres"):
			var file_path = path + "/" + file_name
			file_paths.append(file_path)
		file_name = dir.get_next()
	return file_paths
