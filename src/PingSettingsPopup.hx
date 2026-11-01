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

	static inline final H = 350.0;

	static inline final SCALE = 1.8;

	/** The centre of the popup symbol's frame, which the popup keeps. */
	static inline final CX = 380.0;

	static inline final CY = 253.0;

	/** Over the game's options, which are on the popup layer. */
	static inline final LAYER = 106;

	static inline final MARGIN = 40.0;

	static inline final ROWS_TOP = 72.0;

	static inline final ROW = 40.0;

	/** Where the choices start, from the inner left edge, and how far apart they are. */
	static inline final CHOICES_X = 230.0;

	static inline final CHOICE_GAP = 100.0;

	static inline final BUTTON_SCALE = 0.7;

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

	var changed:Void->Void;

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

	/** `changed` runs after each change; `onClose` once closed. */
	public function new(facade:DBFacade, art:PingArt, settings:PingSettings, changed:Void->Void, onClose:Void->Void) {
		this.facade = facade;
		this.art = art;
		this.settings = settings;
		this.changed = changed;
		this.onClose = onClose;

		frame = art.popup();
		layoutFrame();
		labels = PingArt.outlined();
		var left = CX - W / 2 + MARGIN;

		heading(0, "PING KEY");
		keyButton = option(choiceX(0), rowY(0), "", function() {
			waitingForKey = true;
			refresh();
		});
		keyLabel = keyButton.label;

		heading(1, "WHEEL DELAY");
		delays = choices(1, PingSettings.DELAY_NAMES, function(i) settings.delay = i);
		heading(2, "PING SIZE");
		sizes = choices(2, PingSettings.SIZE_NAMES, function(i) settings.size = i);
		heading(3, "PING SOUNDS");
		sounds = choices(3, ["ON", "OFF"], function(i) settings.sounds = i == 0);
		heading(4, "OTHERS' PINGS");
		others = choices(4, ["SHOW", "HIDE"], function(i) settings.others = i == 0);

		heading(5, "QUICK PING");
		quickIcon = new Sprite();
		quickIcon.x = left + CHOICES_X - 34;
		quickIcon.y = rowY(5);
		frame.addChild(quickIcon);
		quickLabel = art.text(true, 13, WHITE, 170, TextFormatAlign.LEFT);
		quickLabel.x = left + CHOICES_X - 16;
		quickLabel.y = rowY(5) - 11;
		labels.addChild(quickLabel);
		resetButton = option(choiceX(2), rowY(5), "RESET", function() {
			settings.quick = null;
			save();
		});

		note = art.text(false, 10, DIM, W - 2 * MARGIN, TextFormatAlign.LEFT);
		note.x = left + 6;
		note.y = rowY(5) + 26;
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
		changed();
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
		quickLabel.text = settings.quick == null ? "PING! (ATTACK! ON ENEMIES)" : settings.quick.label;
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

	function choices(row:Int, names:Array<String>, pick:Int->Void):Array<UIButton> {
		var group:Array<UIButton> = [];
		for (i in 0...names.length)
			group.push(option(choiceX(i), rowY(row), names[i], choose(pick, i)));
		return group;
	}

	/** A callback for one choice, made apart so each keeps its own index. */
	function choose(pick:Int->Void, index:Int):Void->Void {
		return function() {
			pick(index);
			save();
		};
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
