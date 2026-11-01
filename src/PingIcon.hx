package mods.pings;

import openfl.display.Graphics;
import openfl.display.Shape;
import openfl.display.Sprite;

/**
 * The pings' icons, drawn the way the game draws its own art: flat colours, thick dark brown
 * outlines, and the same shapes in that brown a little lower for depth. Each is drawn in a box of
 * 40 units centred on the origin.
 */
class PingIcon {
	public static inline final OUTLINE = 0x3B1E08;

	public static inline final GOLD = 0xF2B53A;

	static inline final WOOD = 0xA85D24;

	static inline final LID = 0xCF7D36;

	static inline final CREAM = 0xFFF3D2;

	static inline final STEEL = 0xE3EAEE;

	static inline final LINE = 3.5;

	static inline final DEPTH = 3;

	/** The icon of `kind`, about `size` pixels tall, centred on its origin. */
	public static function create(kind:PingKind, size:Float):Sprite {
		var icon = new Sprite();
		icon.mouseEnabled = false;
		icon.mouseChildren = false;
		var scale = size / 40;
		draw(icon, kind, scale, true);
		draw(icon, kind, scale, false);
		return icon;
	}

	/** The icon on a dark disc of `radius`, to sit in the game's round widget. */
	public static function badge(kind:PingKind, radius:Float):Sprite {
		var badge = new Sprite();
		var disc = new Shape();
		disc.graphics.beginFill(0x2A170A);
		disc.graphics.drawCircle(0, 0, radius);
		disc.graphics.endFill();
		badge.addChild(disc);
		badge.addChild(create(kind, radius * 1.3));
		return badge;
	}

	/** One layer of the icon: its drop, all in the outline's colour, or the icon itself. */
	static function draw(icon:Sprite, kind:PingKind, scale:Float, drop:Bool):Void {
		var main = drop ? OUTLINE : kind.color;
		if (kind == PingKind.ATTACK) {
			sword(shape(icon, scale, drop, 45), kind, drop);
			sword(shape(icon, scale, drop, -45), kind, drop);
			return;
		}
		var g = shape(icon, scale, drop, 0);
		if (kind == PingKind.LOOK) {
			// A pin, as League's: a diamond with a hollow, pointing down at the spot.
			poly(g, main, [0, -20, 15, -5, 5, 4, 0, 20, -5, 4, -15, -5]);
			if (!drop)
				poly(g, OUTLINE, [0, -11, 6, -5, 0, 1, -6, -5]);
		} else if (kind == PingKind.DANGER) {
			poly(g, main, [0, -19, 20, 15, -20, 15]);
			if (!drop) {
				g.lineStyle();
				poly(g, CREAM, [-3, -8, 3, -8, 2, 4, -2, 4]);
				g.beginFill(CREAM);
				g.drawCircle(0, 9.5, 2.7);
				g.endFill();
			}
		} else if (kind == PingKind.ON_MY_WAY) {
			poly(g, main, [-6, -20, 6, -20, 6, -3, 16, -3, 0, 18, -16, -3, -6, -3]);
		} else if (kind == PingKind.LOOT) {
			// A treasure chest.
			g.beginFill(drop ? OUTLINE : WOOD);
			g.drawRect(-17, -3, 34, 18);
			g.endFill();
			g.beginFill(drop ? OUTLINE : LID);
			g.moveTo(-17, -3);
			g.lineTo(-17, -9);
			g.curveTo(0, -23, 17, -9);
			g.lineTo(17, -3);
			g.lineTo(-17, -3);
			g.endFill();
			if (!drop) {
				g.beginFill(main);
				g.drawRect(-18, -5, 36, 4);
				g.drawRect(-4.5, -7, 9, 11);
				g.endFill();
				g.lineStyle();
				g.beginFill(OUTLINE);
				g.drawCircle(0, -2.5, 1.8);
				g.endFill();
			}
		} else if (kind == PingKind.HELP) {
			poly(g, main, [-6, -18, 6, -18, 6, -6, 18, -6, 18, 6, 6, 6, 6, 18, -6, 18, -6, 6, -18, 6, -18, -6, -6, -6]);
		} else if (kind == PingKind.WAIT) {
			// An hourglass.
			poly(g, drop ? OUTLINE : CREAM, [-10, -14, 10, -14, 2, 0, 10, 14, -10, 14, -2, 0]);
			if (!drop) {
				g.lineStyle();
				poly(g, GOLD, [-6, -12, 6, -12, 0, -5]);
				poly(g, GOLD, [-8, 12.5, 8, 12.5, 0, 6]);
				g.lineStyle(LINE, OUTLINE);
			}
			g.beginFill(main);
			g.drawRect(-14, -20, 28, 6);
			g.drawRect(-14, 14, 28, 6);
			g.endFill();
		} else if (kind == PingKind.GROUP) {
			// A banner to gather around.
			g.beginFill(drop ? OUTLINE : WOOD);
			g.drawRect(-13, -18, 4.5, 38);
			g.endFill();
			g.beginFill(main);
			g.moveTo(-8.5, -17);
			g.curveTo(4, -22, 17, -15);
			g.lineTo(11, -8);
			g.lineTo(17, -1);
			g.curveTo(4, -6, -8.5, -2);
			g.lineTo(-8.5, -17);
			g.endFill();
			g.beginFill(drop ? OUTLINE : GOLD);
			g.drawCircle(-10.75, -19.5, 3.2);
			g.endFill();
		} else if (kind == PingKind.SECRET) {
			// A question mark, stroked: its outline first, then its colour over it.
			g.lineStyle(13, OUTLINE);
			question(g);
			if (!drop) {
				g.lineStyle(7, main);
				question(g);
			}
			g.lineStyle(LINE, OUTLINE);
			g.beginFill(main);
			g.drawCircle(0, 14, 4.3);
			g.endFill();
		}
	}

	static function shape(icon:Sprite, scale:Float, drop:Bool, rotation:Float):Graphics {
		var shape = new Shape();
		shape.scaleX = shape.scaleY = scale;
		shape.rotation = rotation;
		if (drop)
			shape.y = DEPTH * scale;
		icon.addChild(shape);
		shape.graphics.lineStyle(LINE, OUTLINE);
		return shape.graphics;
	}

	static function sword(g:Graphics, kind:PingKind, drop:Bool):Void {
		poly(g, drop ? OUTLINE : STEEL, [-3.5, -22, 0, -26, 3.5, -22, 3.5, 6, -3.5, 6]);
		g.beginFill(drop ? OUTLINE : WOOD);
		g.drawRect(-2.5, 9, 5, 8);
		g.endFill();
		g.beginFill(drop ? OUTLINE : kind.color);
		g.drawRect(-9, 5, 18, 4.5);
		g.drawCircle(0, 19.5, 3.3);
		g.endFill();
	}

	static function question(g:Graphics):Void {
		g.moveTo(-8, -9);
		g.curveTo(-8, -19, 1, -19);
		g.curveTo(10, -19, 10, -11);
		g.curveTo(10, -5, 3, -2);
		g.curveTo(0, 0, 0, 5);
	}

	/** A closed polygon through `points`, as x, y pairs. */
	static function poly(g:Graphics, fill:Int, points:Array<Float>):Void {
		g.beginFill(fill);
		g.moveTo(points[0], points[1]);
		var i = 2;
		while (i < points.length) {
			g.lineTo(points[i], points[i + 1]);
			i += 2;
		}
		g.lineTo(points[0], points[1]);
		g.endFill();
	}
}
