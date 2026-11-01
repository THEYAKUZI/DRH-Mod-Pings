package mods.pings;

/** A kind of ping: its callout, its colour and its sound, one of the game's own. */
class PingKind {
	public static var LOOK = new PingKind("l", "PING!", "Look here!", 0x3EC6F0, "TEMP_DooberGold1");

	public static var ATTACK = new PingKind("a", "ATTACK!", "Attack!", 0xFFC12E, "TEMP_MetalHit2");

	public static var LOOT = new PingKind("t", "LOOT!", "Loot here!", 0xFFC12E, "TEMP_DooberGoldLarge1");

	public static var HELP = new PingKind("h", "HELP!", "Help me!", 0x58C93A, "TEMP_Heartbeat1");

	public static var WAIT = new PingKind("w", "WAIT!", "Wait up!", 0xA463E0, "TEMP_SwitchHit2b");

	public static var GROUP = new PingKind("g", "GROUP UP!", "Group up!", 0x58C93A, "TEMP_SwitchHit1");

	public static var SECRET = new PingKind("s", "SECRET?", "Secret here?", 0xFFC12E, "TEMP_SpecterTeleportIn");

	public static var DANGER = new PingKind("d", "DANGER!", "Danger!", 0xE8392B, "TEMP_BuffBad1");

	public static var ON_MY_WAY = new PingKind("o", "ON MY WAY!", "On my way!", 0x3F6FE8, "TEMP_SwitchHit1b");

	/** The wheel's slices, clockwise from the right, 45 degrees apart. Its centre is LOOK, or ATTACK on an enemy. */
	public static var WHEEL = [ATTACK, LOOT, HELP, WAIT, GROUP, SECRET, DANGER, ON_MY_WAY];

	public static var ALL = [LOOK, ATTACK, LOOT, HELP, WAIT, GROUP, SECRET, DANGER, ON_MY_WAY];

	/** What stands for it in a chat line. */
	public var code(default, null):String;

	/** What its marker and the wheel show. */
	public var label(default, null):String;

	/** What players without the mod read in the chat. */
	public var say(default, null):String;

	public var color(default, null):Int;

	/** Its sound in the game's `soundEffects.swf`. */
	public var sound(default, null):String;

	function new(code:String, label:String, say:String, color:Int, sound:String) {
		this.code = code;
		this.label = label;
		this.say = say;
		this.color = color;
		this.sound = sound;
	}

	public static function byCode(code:String):Null<PingKind> {
		for (kind in ALL)
			if (kind.code == code)
				return kind;
		return null;
	}
}
