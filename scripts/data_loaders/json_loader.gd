# JsonLoader
# Reads a JSON file and reports problems with the file path and line number.
class_name JsonLoader
extends RefCounted

## Returns the parsed value, or null when the file is missing or malformed.
## Errors are pushed to the log with enough detail to fix the file.
static func load_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("JsonLoader: file not found: %s" % path)
		return null

	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		push_error("JsonLoader: %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
