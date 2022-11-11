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
	bot.login()


func _on_bot_ready(bot: DiscordBot) -> void:
	bot.set_presence({"activity": {"type": "Game", "name": "Printing LaTeX"}})
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
		
	print("----\n%s\n----" % msg)
	var img := latex2img(msg)
	bot.reply(message, "Tex:", {"files": [{"name": "code.png", "media_type": "image/png", "data": img}]})


func latex2img(latex: String) -> PoolByteArray:
	var tex := laTeXture.new()
	tex.LatexExpression = latex
	tex.MathColor = Color.white
	tex.Fill = true
	tex.FontSize = 80
	tex.Render()
	return tex.get_data().save_png_to_buffer()
