package mods.pings;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;

/** The player's choices, kept in the mod's data folder and saved on every change. */
class PingSettings {
	static inline final FILE = "settings.json";

	/** G. */
	public static inline final DEFAULT_KEY = 71;

	/** What the settings offer for how long the key is held before the wheel opens, and for the size of pings. */
	public static var DELAYS:Array<Float> = [0.1, 0.15, 0.3];

	public static var DELAY_NAMES:Array<String> = ["FAST", "NORMAL", "SLOW"];

	public static var SIZES:Array<Float> = [0.8, 1.0, 1.3];

	public static var SIZE_NAMES:Array<String> = ["SMALL", "NORMAL", "LARGE"];

	/** The middle choice of each. */
	static inline final NORMAL = 1;

	public var key:Int = DEFAULT_KEY;

	/** Index in `DELAYS`. */
	public var delay:Int = NORMAL;

	/** Index in `SIZES`. */
	public var size:Int = NORMAL;

	public var sounds:Bool = true;

	/** Whether the other players' pings show. */
	public var others:Bool = true;

	/** What a tap of the key sends: the callout last picked on the wheel, null for the spot (or an attack on an enemy). */
	public var quick:Null<PingKind>;

	var path:String;

	var log:String->Void;

	public function new(folder:String, log:String->Void) {
		path = folder + "/" + FILE;
		this.log = log;
		load();
	}

	public function hold():Float {
		return DELAYS[delay];
	}

	public function scale():Float {
		return SIZES[size];
	}

	public function save():Void {
		var data = {
			key: key,
			delay: delay,
			size: size,
			sounds: sounds,
			others: others,
			quick: quick == null ? "" : quick.code
		};
		try {
			File.saveContent(path, Json.stringify(data, null, "\t"));
		} catch (error:Dynamic) {
			log("could not save " + FILE + ": " + error);
		}
	}

	function load():Void {
		if (!FileSystem.exists(path))
			return;
		try {
			var data:Dynamic = Json.parse(File.getContent(path));
			if (data.key != null)
				key = Std.int(data.key);
			if (data.delay != null)
				delay = choice(Std.int(data.delay), DELAYS.length);
			if (data.size != null)
				size = choice(Std.int(data.size), SIZES.length);
			if (data.sounds != null)
				sounds = data.sounds == true;
			if (data.others != null)
				others = data.others == true;
			if (data.quick != null)
				quick = PingKind.byCode(Std.string(data.quick));
		} catch (error:Dynamic) {
			log("could not read " + FILE + ", the defaults apply: " + error);
		}
	}

	static function choice(index:Int, count:Int):Int {
		return index >= 0 && index < count ? index : NORMAL;
	}

	/** A key as the settings name it. */
	public static function keyName(code:Int):String {
		if ((code >= 65 && code <= 90) || (code >= 48 && code <= 57))
			return String.fromCharCode(code);
		if (code >= 96 && code <= 105)
			return "NUM " + (code - 96);
		if (code >= 112 && code <= 123)
			return "F" + (code - 111);
		var index = KEY_CODES.indexOf(code);
		return index >= 0 ? KEY_NAMES[index] : "KEY " + code;
	}

	static var KEY_CODES:Array<Int> = [
		8, 9, 16, 17, 18, 20, 32, 33, 34, 35, 36, 37, 38, 39, 40, 45, 46, 186, 187, 188, 189, 190, 191, 192, 219, 220, 221, 222
	];

	static var KEY_NAMES:Array<String> = [
		"BACKSPACE", "TAB", "SHIFT", "CTRL", "ALT", "CAPS LOCK", "SPACE", "PAGE UP", "PAGE DOWN", "END", "HOME", "LEFT", "UP", "RIGHT", "DOWN",
		"INSERT", "DELETE", ";", "=", ",", "-", ".", "/", "`", "[", "\\", "]", "'"
	];
}
