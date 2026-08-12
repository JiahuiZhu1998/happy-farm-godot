extends Control

## Login scene controller.

@onready var username_field: LineEdit = %UsernameField
@onready var password_field: LineEdit = %PasswordField
@onready var error_label: Label = %ErrorLabel
@onready var login_button: Button = %LoginButton
@onready var register_link: Button = %RegisterLink


func _ready() -> void:
	error_label.text = ""
	login_button.pressed.connect(_on_login_pressed)
	register_link.pressed.connect(_on_register_pressed)
	password_field.secret = true


func _on_login_pressed() -> void:
	error_label.text = ""
	var username := username_field.text.strip_edges()
	var password := password_field.text

	# Basic format validation
	if username.length() < 3 or username.length() > 10:
		error_label.text = "Username must be 3–10 characters."
		return
	if password.length() < 6 or password.length() > 12:
		error_label.text = "Password must be 6–12 characters."
		return

	# Load save and check credentials
	var save_data := SaveManager.load_game()
	if save_data.profile.is_empty():
		error_label.text = "No account found. Please register first."
		return

	var stored_username: String = save_data.profile.get("username", "")
	var stored_hash: String = save_data.profile.get("password_hash", "")
	var input_hash := _hash_password(password)

	if stored_username != username or stored_hash != input_hash:
		error_label.text = "Incorrect username or password."
		return

	GameState.apply_save(save_data)
	get_tree().change_scene_to_file("res://scenes/farm/farm.tscn")


func _on_register_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/register/register.tscn")


## SHA-256 hash of the password string (hex string output).
func _hash_password(password: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(password.to_utf8_buffer())
	var result := ctx.finish()
	return result.hex_encode()
