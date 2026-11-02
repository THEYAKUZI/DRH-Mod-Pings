package mods.pings;

/**
 * A ping as it travels: a chat line that reads as a callout for players without the mod, ending
 * with a tag that carries the ping for those with it, `Danger! [p:d:1234:-567]`, or
 * `Attack Golem Boss! [p:a:1234:-567:88]` with the object id of the enemy it marks.
 *
 * The tag can also be hidden: written in zero-width characters after the callout, which players
 * without the mod see as just `Danger!`. Both forms are read.
 */
class PingChat {
	/** Longest enemy name a line carries. */
	static inline final NAME_LENGTH = 24;

	/** Starts a hidden tag (invisible separator). */
	static inline final HIDDEN_START = 0x2063;

	/** The four zero-width characters a hidden tag is written in: two bits each, four to a character. */
	static var HIDDEN_DIGITS:Array<Int> = [0x200B, 0x200C, 0x200D, 0x2060];

	public var kind(default, null):PingKind;

	/** World position. */
	public var x(default, null):Int;

	public var y(default, null):Int;

	/** Object id of the enemy it marks, 0 for none. */
	public var target(default, null):Int;

	function new(kind:PingKind, x:Int, y:Int, target:Int) {
		this.kind = kind;
		this.x = x;
		this.y = y;
		this.target = target;
	}

	/** The line for a ping; with `hidden`, its tag in zero-width characters. */
	public static function encode(kind:PingKind, x:Float, y:Float, target:Int, targetName:Null<String>, hidden:Bool):String {
		var text = kind.say;
		if (targetName != null && targetName != "") {
			var name = targetName.length > NAME_LENGTH ? targetName.substr(0, NAME_LENGTH) : targetName;
			text = kind == PingKind.ATTACK ? "Attack " + name + "!" : text + " (" + name + ")";
		}
		var fields = kind.code + ":" + Math.round(x) + ":" + Math.round(y);
		if (target > 0)
			fields += ":" + target;
		return hidden ? text + hide(fields) : text + " [p:" + fields + "]";
	}

	/** `fields` in zero-width characters, after the start mark. */
	static function hide(fields:String):String {
		var out = new StringBuf();
		out.addChar(HIDDEN_START);
		for (i in 0...fields.length) {
			var code = fields.charCodeAt(i);
			var shift = 6;
			while (shift >= 0) {
				out.addChar(HIDDEN_DIGITS[(code >> shift) & 3]);
				shift -= 2;
			}
		}
		return out.toString();
	}

	/** The fields of a hidden tag in `line`, or null when it has none. */
	static function reveal(line:String):Null<String> {
		var start = line.indexOf(String.fromCharCode(HIDDEN_START));
		if (start < 0)
			return null;
		var out = new StringBuf();
		var code = 0;
		var count = 0;
		for (i in start + 1...line.length) {
			var digit = HIDDEN_DIGITS.indexOf(line.charCodeAt(i));
			if (digit < 0)
				break;
			code = (code << 2) | digit;
			count++;
			if (count == 4) {
				out.addChar(code);
				code = 0;
				count = 0;
			}
		}
		return out.toString();
	}

	/** The ping a chat line carries, or null for any other line. */
	public static function parse(line:Null<String>):Null<PingChat> {
		if (line == null)
			return null;
		var hidden = reveal(line);
		var fields:Array<String>;
		if (hidden != null)
			fields = hidden.split(":");
		else {
			var text = StringTools.trim(line);
			var start = text.lastIndexOf("[p:");
			if (start < 0 || !StringTools.endsWith(text, "]"))
				return null;
			fields = text.substring(start + 3, text.length - 1).split(":");
		}
		if (fields.length < 3 || fields.length > 4)
			return null;
		var kind = PingKind.byCode(fields[0]);
		var x = Std.parseInt(fields[1]);
		var y = Std.parseInt(fields[2]);
		var target = fields.length == 4 ? Std.parseInt(fields[3]) : 0;
		if (kind == null || x == null || y == null || target == null)
			return null;
		return new PingChat(kind, x, y, target);
	}
}
