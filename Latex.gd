extends DiscordBot
class_name LaTeXbot

const laTeXture := preload("./addons/GodoTeX/LaTeXture.cs")

var max_height := 200

func compile(source: String) -> RegEx:
	var reg := RegEx.new()
	reg.compile(source)
	return reg


func _ready() -> void:
	var file := File.new()
	var err := file.open("res://token", File.READ)
	if err == OK:
		TOKEN = file.get_as_text()
	elif OS.has_environment("TOKEN"):
		TOKEN = OS.get_environment("TOKEN")
	else:
		push_error("token missing")
	file.close()
	connect("bot_ready", self, "_on_bot_ready")
	connect("message_create", self, "_on_message_create")
	connect("interaction_create", self, "_on_interaction_create")
	login()


func _on_bot_ready(_bot: DiscordBot) -> void:
	set_presence({"activity": {"type": "Game", "name": "Printing LaTeX"}})
	var latex_cmd: ApplicationCommand = ApplicationCommand.new() \
	  .set_name("latex") \
	  .add_option(ApplicationCommand.string_option("latex", "The LaTeX to render", { required = true })) \
	  .set_description("Render LaTeX")
	register_command(latex_cmd)
	print("Logged in as " + user.username + "#" + user.discriminator)
	print("Listening on " + str(channels.size()) + " channels and " + str(guilds.size()) + " guilds.")


func _on_message_create(_bot: DiscordBot, message: Message, _channel: Dictionary) -> void:
	if message.author.bot:
		return
	var msg: String
	var reg := compile("`{3}(la)?tex([^`]+)`{3}")
	var res := reg.search(message.content)
	if res:
		msg = res.strings[2]
	else:
		var reg2 := compile("!(la)?tex\\s*([\\s\\S]+)")
		var res2 := reg2.search(message.content)
		if !res2:
			return
		msg = res2.strings[2]

	msg = msg.strip_edges()

	if !msg:
		return
		
	var img := latex2img(msg)
	reply(message, "", {"files": [{"name": "latex.png", "media_type": "image/png", "data": img}]})

func _on_interaction_create(_bot: DiscordBot, interaction: DiscordInteraction) -> void:
	if not interaction.is_command():
		return

	var command_data := interaction.data

	match command_data.name:
		"latex":
			var pay: String = command_data.options[0].value.strip_edges()
			if pay:
				interaction.defer_reply();
				var img := latex2img(command_data.options[0].value)
				interaction.edit_reply({"files": [{"content": "", "name": "latex.png", "media_type": "image/png", "data": img}]})
			else:
				interaction.reply({"content": "Bad latex"})
		_:
			interaction.reply({"content": "Invalid command"})
	

func latex2img(latex: String) -> PoolByteArray:
	print_debug("----\n%s\n----" % latex)
	var t := Time.get_ticks_usec()
	var tex := laTeXture.new()
	tex.LatexExpression = latex
	tex.MathColor = Color.white
	tex.Fill = true
	tex.FontSize = 80
	tex.Render()
	while tex.get_height() > max_height:
		tex.FontSize /= 2
		tex.Render()
	print_debug("took %.2f seconds" % ((Time.get_ticks_usec() - t) / 1000000.0))
	return tex.get_data().save_png_to_buffer()
