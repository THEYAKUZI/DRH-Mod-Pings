package mods.pings;

import brain.uI.UIButton;
import dBGlobals.DBGlobal;
import facade.DBFacade;
import openfl.display.DisplayObject;
import openfl.display.MovieClip;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormatAlign;

/**
 * The ping settings, opened from the game's options: the game's town popup with a row per setting
 * and the game's buttons to pick from. Every change is saved at once.
 */
class PingSettingsPopup {
	/** The popup's size in its own units; the game shows its popups at `SCALE`. */
	static inline final W = 560.0;

	static inline final H = 340.0;

	static inline final SCALE = 1.8;

	/** The centre of the popup symbol's frame, which the popup keeps. */
	static inline final CX = 380.0;

	static inline final CY = 253.0;

	/** The game's popup layer, where its options are: added after them, the settings show over them. */
	static inline final LAYER = 105;

	static inline final MARGIN = 40.0;

	static inline final ROWS_TOP = 64.0;

	static inline final ROW = 40.0;

	/** Where the choices start, from the inner left edge, and how far apart they are. */
	static inline final CHOICES_X = 230.0;

	static inline final CHOICE_GAP = 100.0;

	static inline final BUTTON_SCALE = 0.7;

	/** The rows, top to bottom. */
	static inline final ROW_KEY = 0;

	static inline final ROW_DELAY = 1;

	static inline final ROW_SIZE = 2;

	static inline final ROW_SOUNDS = 3;

	static inline final ROW_OTHERS = 4;

	static inline final ROW_QUICK = 5;

	/**
	 * The two-way choices. Kept here: a list written straight in a call, as `choices(row, ["ON", "OFF"])`,
	 * crashes the game's script runtime.
	 */
	static var SOUND_NAMES:Array<String> = ["ON", "OFF"];

	static var OTHERS_NAMES:Array<String> = ["SHOW", "HIDE"];

	static inline final ESCAPE = 27;

	static inline final ENTER = 13;

	static inline final GOLD = 0xFFCC00;

	static inline final WHITE = 0xFFFFFF;

	static inline final DIM = 0xB8A48C;

	/** Whether the next key pressed becomes the ping key. */
	public var waitingForKey(default, null):Bool = false;

	var facade:DBFacade;

	var art:PingArt;

	var settings:PingSettings;

	var onClose:Void->Void;

	var holder:Sprite;

	var frame:MovieClip;

	var labels:Sprite;

	var buttons:Array<UIButton> = [];

	var closeButton:UIButton;

	var keyButton:UIButton;

	var keyLabel:Null<TextField>;

	var delays:Array<UIButton>;

	var sizes:Array<UIButton>;

	var sounds:Array<UIButton>;

	var others:Array<UIButton>;

	var resetButton:UIButton;

	var quickIcon:Sprite;

	var quickLabel:TextField;

	var note:TextField;

	var open:Bool = true;

	/** `onClose` runs once closed. */
	public function new(facade:DBFacade, art:PingArt, settings:PingSettings, onClose:Void->Void) {
		this.facade = facade;
		this.art = art;
		this.settings = settings;
		this.onClose = onClose;

		frame = art.popup();
		layoutFrame();
		labels = PingArt.outlined();
		var left = CX - W / 2 + MARGIN;

		heading(ROW_KEY, "PING KEY");
		keyButton = option(choiceX(0), rowY(ROW_KEY), "", choose(ROW_KEY, 0));
		keyLabel = keyButton.label;

		heading(ROW_DELAY, "WHEEL DELAY");
		delays = choices(ROW_DELAY, PingSettings.DELAY_NAMES);
		heading(ROW_SIZE, "PING SIZE");
		sizes = choices(ROW_SIZE, PingSettings.SIZE_NAMES);
		heading(ROW_SOUNDS, "PING SOUNDS");
		sounds = choices(ROW_SOUNDS, SOUND_NAMES);
		heading(ROW_OTHERS, "OTHERS' PINGS");
		others = choices(ROW_OTHERS, OTHERS_NAMES);

		heading(ROW_QUICK, "QUICK PING");
		quickIcon = new Sprite();
		quickIcon.x = left + CHOICES_X - 34;
		quickIcon.y = rowY(ROW_QUICK);
		frame.addChild(quickIcon);
		quickLabel = art.text(true, 13, WHITE, 170, TextFormatAlign.LEFT);
		quickLabel.x = left + CHOICES_X - 16;
		quickLabel.y = rowY(ROW_QUICK) - 11;
		labels.addChild(quickLabel);
		resetButton = option(choiceX(2), rowY(ROW_QUICK), "RESET", choose(ROW_QUICK, 0));

		note = art.text(false, 10, DIM, W - 2 * MARGIN, TextFormatAlign.LEFT);
		note.x = left + 6;
		note.y = rowY(ROW_QUICK) + 26;
		labels.addChild(note);

		frame.addChild(labels);
		frame.scaleX = frame.scaleY = SCALE;
		holder = new Sprite();
		holder.addChild(frame);
		facade.sceneGraphManager.addChild(holder, LAYER);
		frame.x = facade.stageRef.stageWidth / 2 - CX * SCALE;
		frame.y = facade.stageRef.stageHeight / 2 - CY * SCALE;
		refresh();
	}

	/** A key pressed while one is awaited becomes the ping key; Escape cancels. Returns whether it was taken. */
	public function keyPressed(code:Int):Bool {
		if (!waitingForKey)
			return false;
		// Enter opens the chat: it stays out of reach.
		if (code == ENTER)
			return true;
		waitingForKey = false;
		if (code != ESCAPE) {
			settings.key = code;
			save();
		} else
			refresh();
		return true;
	}

	public function close():Void {
		if (!open)
			return;
		open = false;
		waitingForKey = false;
		facade.sceneGraphManager.removeChild(holder);
		closeButton.destroy();
		for (button in buttons)
			button.destroy();
		onClose();
	}

	function save():Void {
		settings.save();
		refresh();
	}

	/** Shows the settings as they are. */
	function refresh():Void {
		if (keyLabel != null)
			keyLabel.text = waitingForKey ? "PRESS A KEY" : PingSettings.keyName(settings.key);
		keyButton.selected = waitingForKey;
		mark(delays, settings.delay);
		mark(sizes, settings.size);
		mark(sounds, settings.sounds ? 0 : 1);
		mark(others, settings.others ? 0 : 1);
		while (quickIcon.numChildren > 0)
			quickIcon.removeChildAt(0);
		quickIcon.addChild(PingIcon.create(settings.quick == null ? PingKind.LOOK : settings.quick, 22));
		quickLabel.text = settings.quick == null ? "DEFAULT: PING!" : settings.quick.label;
		resetButton.enabled = settings.quick != null;
		note.text = waitingForKey ? "PRESS THE KEY TO PING WITH, OR ESC TO KEEP " + PingSettings.keyName(settings.key) : "PICK A CALLOUT ON THE WHEEL AND IT BECOMES YOUR QUICK PING: A TAP SENDS IT";
	}

	static function mark(group:Array<UIButton>, chosen:Int):Void {
		for (i in 0...group.length)
			group[i].selected = i == chosen;
	}

	function heading(row:Int, text:String):Void {
		var label = art.text(true, 14, GOLD, 180, TextFormatAlign.LEFT);
		label.text = text;
		label.x = CX - W / 2 + MARGIN + 6;
		label.y = rowY(row) - 12;
		labels.addChild(label);
	}

	function choices(row:Int, names:Array<String>):Array<UIButton> {
		var group:Array<UIButton> = [];
		for (i in 0...names.length)
			group.push(option(choiceX(i), rowY(row), names[i], choose(row, i)));
		return group;
	}

	/**
	 * A button's callback, made apart so each keeps its own row and index. Only numbers are caught in
	 * it: handing a small function to each row to set its setting crashed the game's script runtime.
	 */
	function choose(row:Int, index:Int):Void->Void {
		return function() pick(row, index);
	}

	/** A button pressed: the `index`th of the row `row`. */
	function pick(row:Int, index:Int):Void {
		if (row == ROW_KEY) {
			waitingForKey = true;
			refresh();
			return;
		}
		if (row == ROW_DELAY)
			settings.delay = index;
		else if (row == ROW_SIZE)
			settings.size = index;
		else if (row == ROW_SOUNDS)
			settings.sounds = index == 0;
		else if (row == ROW_OTHERS)
			settings.others = index == 0;
		else if (row == ROW_QUICK)
			settings.quick = null;
		save();
	}

	/** One of the game's buttons, at a smaller size. */
	function option(x:Float, y:Float, text:String, pick:Void->Void):UIButton {
		var clip = art.button();
		clip.scaleX = clip.scaleY = BUTTON_SCALE;
		clip.x = x;
		clip.y = y;
		var label = clip.getChildByName("label");
		if (Std.isOfType(label, TextField))
			(cast label : TextField).text = text;
		frame.addChild(clip);
		var button = new UIButton(facade, clip);
		button.rolloverFilter = DBGlobal.UI_ROLLOVER_FILTER;
		button.selectedFilter = DBGlobal.UI_SELECTED_FILTER;
		button.releaseCallback = pick;
		buttons.push(button);
		return button;
	}

	static function rowY(row:Int):Float {
		return CY - H / 2 + ROWS_TOP + ROW * row;
	}

	static function choiceX(column:Int):Float {
		return CX - W / 2 + MARGIN + CHOICES_X + CHOICE_GAP * column;
	}

	/** The town popup, stretched to the settings as the game stretches it for its larger popups. */
	function layoutFrame():Void {
		for (name in ["message_label", "left_button", "center_button", "right_button", "content"]) {
			var child = frame.getChildByName(name);
			if (child != null)
				child.visible = false;
		}
		var top = CY - H / 2;
		var base = frame.getChildByName("popup_base");
		fit(base, W, H);
		base.x = CX;
		base.y = CY;

		var banner = frame.getChildByName("banner_title_label");
		fit(banner, W * 0.7, banner.height * 1.3);
		banner.x = CX;
		banner.y = top - 4;
		var title:TextField = cast frame.getChildByName("title_label");
		var format = title.defaultTextFormat;
		format.size = 24;
		format.align = TextFormatAlign.CENTER;
		title.defaultTextFormat = format;
		title.width = W * 0.7;
		title.height = 40;
		title.x = CX - title.width / 2;
		title.y = banner.y - 16;
		title.text = "PING SETTINGS";

		var cross:MovieClip = cast frame.getChildByName("close");
		cross.x = CX + W / 2 - 6;
		cross.y = top + 8;
		closeButton = new UIButton(facade, cross);
		closeButton.rolloverFilter = DBGlobal.UI_ROLLOVER_FILTER;
		closeButton.releaseCallback = close;
	}

	/** Scales art to a size, from its own size at scale 1. */
	static function fit(target:DisplayObject, width:Float, height:Float):Void {
		target.scaleX = target.scaleY = 1;
		target.scaleX = width / target.width;
		target.scaleY = height / target.height;
	}
}
