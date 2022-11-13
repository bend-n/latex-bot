#if TOOLS
using Godot;
using System;

[Tool]
public class GodoTeX : EditorPlugin {
	public override void _EnterTree() {
		var texture_grey = GD.Load<Texture>("addons/GodoTeX/iconGrey.svg");
		var texture_script = GD.Load<Script>("addons/GodoTeX/LaTeXture.cs");
		AddCustomType("LaTeXture", "ImageTexture", texture_script, texture_grey);
	}

	public override void _ExitTree() {
		RemoveCustomType("LaTeXture");
	}
}
#endif

