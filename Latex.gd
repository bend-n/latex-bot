extends Node

const laTeXture := preload("./addons/GodoTeX/LaTeXture.cs")


func compile(source: String) -> RegEx:
	var reg := RegEx.new()
	reg.compile(source)
	return reg


func _ready() -> void:
	var bot := DiscordBot.new()
	add_child(bot)
	var file := File.new()
	var err := file.open("res://token", File.READ)
	var token: String
	if err == OK:
		token = file.get_as_text()
	elif OS.has_environment("TOKEN"):
		token = OS.get_environment("TOKEN")
	else:
		push_error("token missing")
	file.close()
	bot.TOKEN = token
	bot.connect("bot_ready", self, "_on_bot_ready")
	bot.connect("message_create", self, "_on_message_create")
	bot.connect("interaction_create", self, "_on_interaction_create")
	bot.login()


func _on_bot_ready(bot: DiscordBot) -> void:
	bot.set_presence({"activity": {"type": "Game", "name": "Printing LaTeX"}})
	var latex_cmd: ApplicationCommand = ApplicationCommand.new() \
	  .set_name("latex") \
	  .add_option(ApplicationCommand.string_option("latex", "The LaTeX to render", { required = true })) \
	  .set_description("Render LaTeX")
	bot.register_command(latex_cmd)
	print("Logged in as " + bot.user.username + "#" + bot.user.discriminator)
	print("Listening on " + str(bot.channels.size()) + " channels and " + str(bot.guilds.size()) + " guilds.")


func _on_message_create(bot: DiscordBot, message: Message, _channel: Dictionary) -> void:
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
	bot.reply(message, "Tex:", {"files": [{"name": "latex.png", "media_type": "image/png", "data": img}]})

func _on_interaction_create(_bot: DiscordBot, interaction: DiscordInteraction) -> void:
	if not interaction.is_command():
		return

	var command_data := interaction.data

	match command_data.name:
		"latex":
			var pay: String = command_data.options[0].value.strip_edges()
			if pay:
				interaction.defer_reply();
				var t := Time.get_ticks_usec()
				var img := latex2img(command_data.options[0].value)
				print_debug("took %.2f seconds" % ((Time.get_ticks_usec() - t) / 1000000.0))
				interaction.edit_reply({"files": [{"content": "", "name": "latex.png", "media_type": "image/png", "data": img}]})
			else:
				interaction.reply({"content": "Bad latex"})
		_:
			interaction.reply({"content": "Invalid command"})
	

func latex2img(latex: String) -> PoolByteArray:
	print_debug("----\n%s\n----" % latex)
	var tex := laTeXture.new()
	tex.LatexExpression = latex
	tex.MathColor = Color.white
	tex.Fill = true
	tex.FontSize = 80
	tex.Render()
	return tex.get_data().save_png_to_buffer()
