package mods.pings;

import openfl.display.Graphics;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.text.TextField;

/**
 * The ping wheel: eight callouts around a centre that pings the spot itself, or attacks the enemy
 * on it. A dark disc with gold rims, as the game's round frames, and the callout under the cursor
 * written in the middle.
 */
class PingWheel {
	static inline final OUTER = 118;

	static inline final INNER = 40;

	static inline final ICON_RING = 80;

	static inline final ICON_SIZE = 34;

	static inline final SLICE = 45;

	static inline final FILL = 0x24130A;

	static inline final HOVER = 0xFFD76A;

	static inline final SEAM = 0xC8913A;

	/** The widget's own label colour. */
	static inline final LABEL = 0xFFCC66;

	static inline final TICK_GREEN = 0x58C93A;

	/** Where the tick sits: up right of a slice's icon, or of the centre's. */
	static inline final TICK_OFFSET = 16.0;

	static inline final TICK_CENTRE_X = 20.0;

	static inline final TICK_CENTRE_Y = -24.0;

	public var root(default, null):Sprite;

	public var shown(get, never):Bool;

	/** The callout under the cursor: a slice, or the centre. */
	public var selected(default, null):PingKind;

	/** Whether the cursor is on the centre. */
	public var onCentre(get, never):Bool;

	/** Marks the quick ping, which a tap of the key sends. */
	var tick:Shape;

	var centre:PingKind;

	var back:Shape;

	var icons:Array<Sprite> = [];

	var centreIcon:Null<Sprite>;

	var label:TextField;

	/** The slice under the cursor, -1 for the centre. */
	var hovered:Int = -2;

	var age:Float = 0;

	public function new(art:PingArt) {
		centre = PingKind.LOOK;
		selected = centre;
		root = new Sprite();
		root.mouseEnabled = false;
		root.mouseChildren = false;
		root.visible = false;
		back = new Shape();
		root.addChild(back);
		for (i in 0...PingKind.WHEEL.length) {
			var icon = PingIcon.create(PingKind.WHEEL[i], ICON_SIZE);
			var angle = i * SLICE * Math.PI / 180;
			icon.x = Math.cos(angle) * ICON_RING;
			icon.y = Math.sin(angle) * ICON_RING;
			root.addChild(icon);
			icons.push(icon);
		}
		label = art.title(13, LABEL, 120);
		label.x = -60;
		label.y = 8;
		root.addChild(label);
		tick = new Shape();
		drawTick(tick.graphics);
		root.addChild(tick);
	}

	function get_shown():Bool {
		return root.visible;
	}

	function get_onCentre():Bool {
		return hovered < 0;
	}

	/** Opens on `x`, `y`, its centre being `centre`; the tick on `quick`, or on the centre when null. */
	public function show(x:Float, y:Float, centre:PingKind, quick:Null<PingKind>):Void {
		this.centre = centre;
		if (centreIcon != null)
			root.removeChild(centreIcon);
		centreIcon = PingIcon.create(centre, 26);
		centreIcon.y = -9;
		root.addChild(centreIcon);
		var slice = quick == null ? -1 : PingKind.WHEEL.indexOf(quick);
		if (slice < 0) {
			tick.x = TICK_CENTRE_X;
			tick.y = TICK_CENTRE_Y;
		} else {
			tick.x = icons[slice].x + TICK_OFFSET;
			tick.y = icons[slice].y - TICK_OFFSET;
		}
		root.setChildIndex(tick, root.numChildren - 1);
		root.x = x;
		root.y = y;
		root.visible = true;
		age = 0;
		hovered = -2;
		select(-1);
	}

	public function hide():Void {
		root.visible = false;
	}

	/** Pops open, and follows the cursor, at `mouseX`, `mouseY` in the wheel's parent. */
	public function update(dt:Float, mouseX:Float, mouseY:Float):Void {
		age += dt;
		var scale = age < 0.14 ? 0.7 + 0.3 * backOut(age / 0.14) : 1;
		root.scaleX = root.scaleY = scale;
		var dx = mouseX - root.x;
		var dy = mouseY - root.y;
		if (dx * dx + dy * dy < INNER * INNER) {
			select(-1);
			return;
		}
		var slice = Math.round(Math.atan2(dy, dx) * 180 / Math.PI / SLICE);
		select(((slice % 8) + 8) % 8);
	}

	function select(index:Int):Void {
		if (index == hovered)
			return;
		hovered = index;
		selected = index < 0 ? centre : PingKind.WHEEL[index];
		for (i in 0...icons.length) {
			var on = i == index;
			icons[i].scaleX = icons[i].scaleY = on ? 1.3 : 1;
			icons[i].alpha = on ? 1 : 0.8;
		}
		label.text = selected.label;
		draw();
	}

	function draw():Void {
		var g = back.graphics;
		g.clear();
		g.beginFill(FILL, 0.72);
		g.drawCircle(0, 0, OUTER);
		g.drawCircle(0, 0, INNER);
		g.endFill();
		if (hovered >= 0) {
			g.beginFill(HOVER, 0.38);
			wedge(g, hovered * SLICE);
			g.endFill();
		}
		g.beginFill(hovered < 0 ? 0x4A2A12 : 0x2A170A, 0.92);
		g.drawCircle(0, 0, INNER);
		g.endFill();
		g.lineStyle(2, SEAM, 0.6);
		for (i in 0...8) {
			var angle = (i * SLICE + SLICE / 2) * Math.PI / 180;
			g.moveTo(Math.cos(angle) * INNER, Math.sin(angle) * INNER);
			g.lineTo(Math.cos(angle) * OUTER, Math.sin(angle) * OUTER);
		}
		rim(g, OUTER);
		rim(g, INNER);
	}

	/** A green badge with a white tick, outlined as the wheel. */
	static function drawTick(g:Graphics):Void {
		g.lineStyle(3, PingIcon.OUTLINE);
		g.beginFill(TICK_GREEN);
		g.drawCircle(0, 0, 9);
		g.endFill();
		g.lineStyle(3, 0xFFFFFF);
		g.moveTo(-4.5, 0.5);
		g.lineTo(-1.2, 3.8);
		g.lineTo(4.5, -3.2);
	}

	/** A gold rim with dark edges, as on the game's round frames. */
	static function rim(g:Graphics, radius:Float):Void {
		g.lineStyle(7, PingIcon.OUTLINE);
		g.drawCircle(0, 0, radius);
		g.lineStyle(3.5, PingIcon.GOLD);
		g.drawCircle(0, 0, radius);
	}

	/** The slice centred on `centre` degrees, between the rims. */
	static function wedge(g:Graphics, centre:Float):Void {
		var steps = 10;
		for (i in 0...steps + 1) {
			var angle = (centre - SLICE / 2 + SLICE * i / steps) * Math.PI / 180;
			if (i == 0)
				g.moveTo(Math.cos(angle) * OUTER, Math.sin(angle) * OUTER);
			else
				g.lineTo(Math.cos(angle) * OUTER, Math.sin(angle) * OUTER);
		}
		for (i in 0...steps + 1) {
			var angle = (centre + SLICE / 2 - SLICE * i / steps) * Math.PI / 180;
			g.lineTo(Math.cos(angle) * INNER, Math.sin(angle) * INNER);
		}
	}

	static function backOut(t:Float):Float {
		var u = t - 1;
		return 1 + 2.70158 * u * u * u + 1.70158 * u * u;
	}
}
