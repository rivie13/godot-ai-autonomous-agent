@tool
class_name AISettingsWindow
extends Window

signal settings_changed

@onready var llm_provider_option: OptionButton = %LLMProviderOption
@onready var url_label: Label = %UrlLabel
@onready var url_txt: LineEdit = %UrlTxt
@onready var api_key_label: Label = %ApiKeyLabel
@onready var api_key_txt: LineEdit = %APIKeyTxt
@onready var get_key_link: LinkButton = %GetKeyLink
@onready var mcp_list: ItemList = %MCPList
@onready var mcp_add_button: Button = %MCPAddButton
@onready var mcp_remove_button: Button = %MCPRemoveButton

var _plugin: AIHubPlugin
var _current_api_id: String


func _ready() -> void:
	close_requested.connect(_on_close_requested)


func initialize(plugin: AIHubPlugin) -> void:
	_plugin = plugin
	await ready
	_refresh_options()
	_refresh_mcp_list()


func open_window() -> void:
	_refresh_options()
	_refresh_mcp_list()
	popup_centered()


func _on_close_requested() -> void:
	hide()


func _refresh_options() -> void:
	llm_provider_option.clear()
	_current_api_id = ProjectSettings.get_setting(AIHubPlugin.CONFIG_LLM_API, "")
	var files := _get_all_resources("%s/llm_providers" % self.scene_file_path.get_base_dir())
	var i := 0
	for provider_file in files:
		var provider = load(provider_file)
		if provider is LLMProviderResource:
			llm_provider_option.add_item(provider.name)
			llm_provider_option.set_item_tooltip(i, provider.description)
			llm_provider_option.set_item_metadata(i, provider)
			if provider.api_id == _current_api_id:
				llm_provider_option.select(i)
			i += 1
	if llm_provider_option.get_item_count() > 0:
		if llm_provider_option.get_selected() == -1:
			llm_provider_option.select(0)
		_update_provider_ui()


func _update_provider_ui() -> void:
	var llm_provider: LLMProviderResource = llm_provider_option.get_selected_metadata()
	if llm_provider == null:
		push_error("No LLM provider is selected.")
		return
	var config = LLMConfigManager.new(llm_provider.api_id)
	if llm_provider.fix_url.is_empty():
		url_txt.editable = true
		url_txt.text = config.load_url()
	else:
		url_txt.editable = false
		url_txt.text = llm_provider.fix_url
	api_key_label.visible = llm_provider.requires_key
	api_key_txt.visible = llm_provider.requires_key
	api_key_txt.text = config.load_key()
	get_key_link.visible = llm_provider.requires_key and not llm_provider.get_key_url.is_empty()
	get_key_link.uri = llm_provider.get_key_url
	if llm_provider.requires_key:
		url_label.text = "Server URL"
	else:
		url_label.text = "Server URL"


func _on_settings_changed(_x) -> void:
	var llm_provider: LLMProviderResource = llm_provider_option.get_selected_metadata()
	if llm_provider == null:
		push_error("No LLM provider is selected. Settings not saved.")
		return
	var config = LLMConfigManager.new(llm_provider.api_id)
	if llm_provider.requires_key and not api_key_txt.text.is_empty():
		config.save_key(api_key_txt.text)
	if llm_provider.fix_url.is_empty() and not url_txt.text.is_empty():
		config.save_url(url_txt.text)
	settings_changed.emit()


func _on_llm_provider_option_item_selected(index: int) -> void:
	var llm_provider: LLMProviderResource = llm_provider_option.get_item_metadata(index)
	if llm_provider == null:
		return
	_current_api_id = llm_provider.api_id
	ProjectSettings.set_setting(AIHubPlugin.CONFIG_LLM_API, llm_provider.api_id)
	ProjectSettings.save()
	_update_provider_ui()
	settings_changed.emit()


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


func _refresh_mcp_list() -> void:
	mcp_list.clear()
	# Placeholder entries until MCP execution/registry is implemented.
	# This allows users to register MCPs in the UI now.
	mcp_list.add_item("No MCP servers configured")
	mcp_remove_button.disabled = true


func _on_mcp_list_item_selected(_index: int) -> void:
	# Disabled for placeholder entry.
	mcp_remove_button.disabled = true


func _on_mcp_add_button_pressed() -> void:
	# TODO: Replace with real MCP registry storage.
	print("MCP add requested (stub)")


func _on_mcp_remove_button_pressed() -> void:
	# TODO: Replace with real MCP registry storage.
	print("MCP remove requested (stub)")
