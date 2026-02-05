@tool
class_name OpenAICompatibleAPI
extends LLMInterface

var _headers: PackedStringArray


func _rebuild_headers() -> void:
	_headers = ["Content-Type: application/json"]
	if not _api_key.is_empty():
		_headers.append("Authorization: Bearer %s" % _api_key)


func _initialize() -> void:
	_rebuild_headers()
	llm_config_changed.connect(_rebuild_headers)


func _requires_key() -> bool:
	return _llm_provider != null and _llm_provider.requires_key


func send_get_models_request(http_request: HTTPRequest) -> bool:
	if _requires_key() and _api_key.is_empty():
		push_error("API key not set. Configure it in AI Assistant Settings.")
		return false
	var error = http_request.request(_models_url, _headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("OpenAI-compatible models request failed: %s" % _models_url)
		return false
	return true


func read_models_response(body: PackedByteArray) -> Array[String]:
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response := json.get_data()
	if response.has("data") and response.data is Array:
		var model_names: Array[String] = []
		for model in response.data:
			if model.has("id"):
				model_names.append(model.id)
		model_names.sort()
		return model_names
	return [INVALID_RESPONSE]


func send_chat_request(http_request: HTTPRequest, content: Array) -> bool:
	if _requires_key() and _api_key.is_empty():
		push_error("API key not set. Configure it in AI Assistant Settings.")
		return false
	if model.is_empty():
		push_error("ERROR: You need to set an AI model for this assistant type.")
		return false
	var body_dict := {
		"model": model,
		"messages": content
	}
	if override_temperature:
		body_dict["temperature"] = temperature
	var body := JSON.stringify(body_dict)
	var error = http_request.request(_chat_url, _headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("OpenAI-compatible chat request failed.\nURL: %s\nBody:\n%s" % [_chat_url, body])
		return false
	return true


func read_response(body: PackedByteArray) -> String:
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response := json.get_data()
	if response.has("choices") and response.choices.size() > 0:
		if response.choices[0].has("message") and response.choices[0].message.has("content"):
			return ResponseCleaner.clean(response.choices[0].message.content)
	return INVALID_RESPONSE
