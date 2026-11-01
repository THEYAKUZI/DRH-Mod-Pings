package mods.pings;

import actor.ActorGameObject;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.display.Graphics;
import openfl.display.MovieClip;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.geom.Point;
import openfl.text.TextField;

/**
 * A ping in the world: its icon standing on two rings on the ground, a ripple when it lands, and
 * the name of who sent it. A ping on an enemy follows it, its icon over its head. Off screen, the
 * game's own round widget takes its place at the edge of the screen, its arrow pointing at the
 * ping, as the game shows teammates out of sight.
 */
class PingMarker {
	static inline final LIFE = 4.0;

	/** On an enemy, unless it dies first. */
	static inline final TARGET_LIFE = 5.0;

	static inline final FADE = 0.35;

	static inline final ICON_SIZE = 40;

	/** Outer ring's half width; the rings are flattened as the game's floor is seen. */
	static inline final RING = 30;

	static inline final FLAT = 0.42;

	static inline final WIDGET_SCALE = 1.2;

	/** Where the off-screen widget may sit, as parts of the view, clear of the HUD at the bottom. */
	static inline final EDGE_SIDE = 0.07;

	static inline final EDGE_TOP = 0.13;

	static inline final EDGE_BOTTOM = 0.24;

	/** The game's widget: where its round frame takes an icon, and that frame's inner radius there. */
	static inline final AVATAR = "UI_avatar";

	static inline final AVATAR_RADIUS = 27;

	public var root(default, null):Sprite;

	public var done(default, null):Bool = false;

	var kind:PingKind;

	var x:Float;

	var y:Float;

	var target:Null<ActorGameObject>;

	/** How far over the target's feet its head is, in world units; 0 for a spot. */
	var lift:Float = 0;

	var age:Float = 0;

	var life:Float;

	var ground:Shape;

	var icon:Sprite;

	var name:TextField;

	var widget:Null<MovieClip>;

	var arrow:Null<DisplayObject>;

	public function new(kind:PingKind, sender:String, x:Float, y:Float, target:Null<ActorGameObject>, art:PingArt) {
		this.kind = kind;
		this.x = x;
		this.y = y;
		this.target = target;
		life = target != null ? TARGET_LIFE : LIFE;
		if (target != null)
			lift = headHeight(target);

		root = new Sprite();
		root.mouseEnabled = false;
		root.mouseChildren = false;
		ground = new Shape();
		root.addChild(ground);
		icon = PingIcon.create(kind, ICON_SIZE);
		root.addChild(icon);
		name = PingArt.name(160);
		name.text = sender;
		root.addChild(name);

		widget = art.widget();
		if (widget != null) {
			setText(widget, "NametagText", sender);
			setText(widget, "AlertText", kind.label);
			var frame = widget.getChildByName(AVATAR);
			if (Std.isOfType(frame, DisplayObjectContainer))
				(cast frame : DisplayObjectContainer).addChild(PingIcon.badge(kind, AVATAR_RADIUS));
			arrow = widget.getChildByName("UI_arrow");
			widget.visible = false;
			root.addChild(widget);
		}
	}

	/** Places the ping for this frame, `world` being the game's world and `space` the overlay, `width` by `height`. */
	public function update(dt:Float, world:DisplayObject, space:DisplayObjectContainer, width:Float, height:Float):Void {
		age += dt;
		if (target != null) {
			if (target.isDestroyed || target.isDead()) {
				// Gone where it was last seen.
				target = null;
				life = Math.min(life, age + FADE);
			} else {
				var position = target.position;
				x = position.x;
				y = position.y;
			}
		}
		if (age >= life) {
			done = true;
			return;
		}
		var alpha = Math.min(1, Math.min(age / 0.1, (life - age) / FADE));
		var foot = space.globalToLocal(world.localToGlobal(new Point(x, y)));
		var onScreen = foot.x >= 0 && foot.x <= width && foot.y >= 0 && foot.y <= height;
		ground.visible = icon.visible = name.visible = onScreen;
		if (widget != null)
			widget.visible = !onScreen;
		if (onScreen)
			showInWorld(foot, world, space, alpha);
		else
			showAtEdge(foot, width, height, alpha);
	}

	function showInWorld(foot:Point, world:DisplayObject, space:DisplayObjectContainer, alpha:Float):Void {
		drawRings(foot.x, foot.y, alpha);
		var head = lift > 0 ? space.globalToLocal(world.localToGlobal(new Point(x, y - lift))) : foot;
		// Drops onto its rings with a bounce, then sways a little.
		var bob = age < 0.35 ? -34 * (1 - backOut(age / 0.35)) : Math.sin((age - 0.35) * 4.5) * 2.5;
		icon.x = head.x;
		icon.y = head.y - ICON_SIZE * 0.55 + bob;
		icon.alpha = alpha;
		name.x = head.x - name.width / 2;
		name.y = icon.y - ICON_SIZE * 0.5 - 20;
		name.alpha = alpha;
	}

	function showAtEdge(foot:Point, width:Float, height:Float, alpha:Float):Void {
		ground.graphics.clear();
		if (widget == null)
			return;
		var left = width * EDGE_SIDE;
		var right = width * (1 - EDGE_SIDE);
		var top = height * EDGE_TOP;
		var bottom = height * (1 - EDGE_BOTTOM);
		// Where the line from the middle of the view to the ping leaves that frame.
		var cx = width / 2;
		var cy = height / 2;
		var dx = foot.x - cx;
		var dy = foot.y - cy;
		var t = 1.0;
		if (dx > 0)
			t = Math.min(t, (right - cx) / dx);
		else if (dx < 0)
			t = Math.min(t, (left - cx) / dx);
		if (dy > 0)
			t = Math.min(t, (bottom - cy) / dy);
		else if (dy < 0)
			t = Math.min(t, (top - cy) / dy);
		widget.x = cx + dx * t;
		widget.y = cy + dy * t;
		// The arrow points left unturned, as the game turns it.
		if (arrow != null)
			arrow.rotation = Math.atan2(foot.y - widget.y, foot.x - widget.x) * 180 / Math.PI + 180;
		var scale = WIDGET_SCALE * (age < 0.3 ? 0.4 + 0.6 * backOut(age / 0.3) : 1);
		widget.scaleX = widget.scaleY = scale;
		widget.alpha = alpha;
	}

	function drawRings(px:Float, py:Float, alpha:Float):Void {
		var g = ground.graphics;
		g.clear();
		var grow = age < 0.25 ? backOut(age / 0.25) : 1;
		ring(g, px, py, RING * grow, 7, 3.5, alpha);
		ring(g, px, py, RING * 0.45 * grow, 5, 2.2, alpha);
		// A ripple runs out as it lands.
		if (age < 0.7) {
			var u = age / 0.7;
			ring(g, px, py, RING + RING * 1.5 * (1 - (1 - u) * (1 - u)), 4, 2.5, alpha * (1 - u));
		}
	}

	/** A flat ring in the ping's colour over a wider one in the outline's. */
	function ring(g:Graphics, px:Float, py:Float, radius:Float, outline:Float, line:Float, alpha:Float):Void {
		if (radius <= 0)
			return;
		var flat = radius * FLAT;
		g.lineStyle(outline, PingIcon.OUTLINE, alpha);
		g.drawEllipse(px - radius, py - flat, radius * 2, flat * 2);
		g.lineStyle(line, kind.color, alpha);
		g.drawEllipse(px - radius, py - flat, radius * 2, flat * 2);
	}

	/** The target's height over its feet, from its art, so its icon floats over its head. */
	static function headHeight(actor:ActorGameObject):Float {
		var view = actor.view;
		if (view == null || view.root == null || view.root.parent == null)
			return 80;
		var bounds = view.root.getBounds(view.root.parent);
		return Math.max(50, Math.min(320, actor.position.y - bounds.top));
	}

	static function setText(clip:MovieClip, child:String, text:String):Void {
		var field = clip.getChildByName(child);
		if (Std.isOfType(field, TextField))
			(cast field : TextField).text = text;
	}

	/** Eases out past the end and back, the bounce of the game's popups. */
	static function backOut(t:Float):Float {
		var u = t - 1;
		return 1 + 2.70158 * u * u * u + 1.70158 * u * u;
	}
}
