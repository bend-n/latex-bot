extends Node

var template_tex := """
\\documentclass[varwidth=true]{standalone}
\\usepackage[utf8]{inputenc}
\\usepackage{xcolor}
\\usepackage{amsmath}

\\color{white}
\\begin{document}

%s

\\end{document}
"""

var f := File.new()
var thread_pool := []


func compile(source: String) -> RegEx:
	var reg := RegEx.new()
	reg.compile(source)
	return reg


func _ready():
	for _i in range(5):
		thread_pool.append(Thread.new())
	var dir = Directory.new()
	if !dir.dir_exists("res://texs"):
		dir.make_dir("texs")
	f.open("res://texs/.gdignore", File.WRITE)  # touch .gdignore
	f.close()
	var bot := DiscordBot.new()
	add_child(bot)
	var file = File.new()
	var err = file.open("res://token", File.READ)
	var token
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


func _on_bot_ready(bot: DiscordBot):
	bot.set_presence({"activity": {"type": "Game", "name": "Printing LaTeX"}})
	print("Logged in as " + bot.user.username + "#" + bot.user.discriminator)
	print("Listening on " + str(bot.channels.size()) + " channels and " + str(bot.guilds.size()) + " guilds.")


func _on_message_create(bot: DiscordBot, message: Message, _channel: Dictionary):
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

	print("----\n%s\n----" % msg)
	if !msg:
		return

	var th: Thread
	for thread in thread_pool:
		if !thread.is_alive():
			th = thread
			break
	if !th:
		thread_pool.append(Thread.new())
		th = thread_pool[-1]

	th.start(self, "latex2img", template_tex % msg)
	while true:
		yield(get_tree(), "idle_frame")
		if !th.is_alive():
			var img = th.wait_to_finish()
			if img is Dictionary:
				bot.reply(message, "No({err}): `{output}`".format(img))
				return
			bot.reply(
				message,
				"Tex:",
				{"files": [{"name": "code.png", "media_type": "image/png", "data": img.save_png_to_buffer()}]}
			)
			return


func _notification(what):
	if what == NOTIFICATION_EXIT_TREE:
		OS.execute("bash", ["-c", "rm -r texs"], false)


func latex2img(latex: String):
	randomize()
	var name := ("%s-%s" % [randi() % 201, randi() % 201]).c_escape()
	f.open("res://texs/%s.tex" % name, File.WRITE_READ)
	f.store_string(latex)
	f.close()
	var output: PoolStringArray = []
	var err = OS.execute(
		"bash", ["-c", "cd texs && latex -interaction=nonstopmode '%s.tex'" % name], true, output, true
	)
	if err:
		return {err = err, output = "(la)" + output.join(" ")}
	output.resize(0)
	var dvipng = [
		"-c",
		"dvipng -strict -bg Transparent --png -Q 250 -D 250 -T tight -o 'texs/%s.png' 'texs/%s.dvi'" % [name, name]
	]
	err = OS.execute("bash", dvipng, true, output, true)
	if err:
		return {err = err, output = "(dvi)" + output.join(" ")}
	var img := Image.new()
	err = img.load("res://texs/%s.png" % name)
	OS.execute("bash", ["-c", "rm 'texs/%s.'*" % name], false)
	return img
