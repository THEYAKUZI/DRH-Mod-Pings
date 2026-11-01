package mods.pings;

/**
 * A ping as it travels: a chat line that reads as a callout for players without the mod, ending
 * with a tag that carries the ping for those with it, `Danger! [p:d:1234:-567]`, or
 * `Attack Golem Boss! [p:a:1234:-567:88]` with the object id of the enemy it marks.
 */
class PingChat {
	/** Longest enemy name a line carries. */
	static inline final NAME_LENGTH = 24;

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

	public static function encode(kind:PingKind, x:Float, y:Float, target:Int, targetName:Null<String>):String {
		var text = kind.say;
		if (targetName != null && targetName != "") {
			var name = targetName.length > NAME_LENGTH ? targetName.substr(0, NAME_LENGTH) : targetName;
			text = kind == PingKind.ATTACK ? "Attack " + name + "!" : text + " (" + name + ")";
		}
		var tag = "[p:" + kind.code + ":" + Math.round(x) + ":" + Math.round(y);
		if (target > 0)
			tag += ":" + target;
		return text + " " + tag + "]";
	}

	/** The ping a chat line carries, or null for any other line. */
	public static function parse(line:Null<String>):Null<PingChat> {
		if (line == null)
			return null;
		var text = StringTools.trim(line);
		var start = text.lastIndexOf("[p:");
		if (start < 0 || !StringTools.endsWith(text, "]"))
			return null;
		var fields = text.substring(start + 3, text.length - 1).split(":");
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
