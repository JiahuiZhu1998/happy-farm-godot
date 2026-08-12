extends Control

## Register scene controller.

@onready var username_field: LineEdit = %UsernameField
@onready var password_field: LineEdit = %PasswordField
@onready var confirm_field: LineEdit = %ConfirmField
@onready var error_label: Label = %ErrorLabel
@onready var register_button: Button = %RegisterButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	error_label.text = ""
	register_button.pressed.connect(_on_register_pressed)
	back_button.pressed.connect(_on_back_pressed)
	password_field.secret = true
	confirm_field.secret = true


func _on_register_pressed() -> void:
	error_label.text = ""
	var username := username_field.text.strip_edges()
	var password := password_field.text
	var confirm := confirm_field.text

	if username.length() < 3 or username.length() > 10:
		error_label.text = "Username must be 3–10 characters."
		return
	if password.length() < 6 or password.length() > 12:
		error_label.text = "Password must be 6–12 characters."
		return
	if password != confirm:
		error_label.text = "Passwords do not match."
		return

	# Check if a save already exists
	var existing := SaveManager.load_game()
	if not existing.profile.is_empty():
		error_label.text = "An account already exists. Please log in."
		return

	var save_data := SaveData.new_game(username, _hash_password(password))
	SaveManager.save_game(save_data)
	GameState.apply_save(save_data)
	get_tree().change_scene_to_file("res://scenes/farm/farm.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/login/login.tscn")


func _hash_password(password: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(password.to_utf8_buffer())
	return ctx.finish().hex_encode()
