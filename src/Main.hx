package mods.pings;

import actor.ActorGameObject;
import actor.player.input.dBMouseEvents.DBMouseEvent;
import brain.gameObject.GameObject;
import distributedObjects.PlayerGameObject;
import distributedObjects.PlayerGameObjectOwner;
import events.ChatEvent;
import events.ChatLogEvent;
import facade.DBFacade;
import haxe.Timer;
import mods.api.Context;
import mods.api.Mod;
import mods.api.dungeon.Monster;
import openfl.display.DisplayObject;
import openfl.events.KeyboardEvent;
import openfl.geom.Point;

/**
 * Pings for callouts in a dungeon, as in MOBAs. Hold G for the wheel and let go on a callout, or tap
 * G to ping the spot under the cursor, or attack the enemy there.
 *
 * A ping travels as a chat line, through the game's own chat. The party's players with this mod see
 * it on the floor, with a sound, and never the line; the others read the line, a plain callout.
 */
class Main extends Mod {
	static inline final KEY_G:UInt = 71;

	static inline final KEY_ESCAPE:UInt = 27;

	/** How long G is held before the wheel shows: a shorter press is a quick ping. */
	static inline final HOLD = 0.15;

	/** At most how many pings the player sends, and how many of one sender show, in `WINDOW` seconds. */
	static inline final SEND_LIMIT = 4;

	static inline final SHOW_LIMIT = 6;

	static inline final WINDOW = 4.0;

	static inline final MAX_MARKERS = 12;

	/** How near the cursor an enemy counts as pinged, in world units. */
	static inline final PICK_RADIUS = 70.0;

	/** Above every listener of the game, all at 0, so a ping line is caught before the chat shows it. */
	static inline final FIRST = 1000;

	/** Above the mod host's key listener, which hides the release of a key a mod keeps. */
	static inline final BEFORE_HOST = 2000;

	/** The game's event for a line a player said, followed by the player's object id. */
	static inline final INCOMING_CHAT = "ChatEvent_INCOMING_CHAT_UPDATE_";

	var ctx:Context;

	var facade:Null<DBFacade>;

	var art:Null<PingArt>;

	var wheel:Null<PingWheel>;

	var markers:Array<PingMarker> = [];

	/** Players whose lines are watched, by object id. */
	var watched:Map<String, Bool> = new Map();

	/** The actor under the cursor, as the game reports it. */
	var hovered:Null<ActorGameObject>;

	var sent:Array<Float> = [];

	var shownBy:Map<String, Array<Float>> = new Map();

	var last:Float = 0;

	/** While G is down: since when, where the wheel opens, the spot it pings and the enemy on it. */
	var armed:Bool = false;

	var armedAt:Float = 0;

	var wheelX:Float = 0;

	var wheelY:Float = 0;

	var spot:Null<Point>;

	var enemy:Null<Monster>;

	// Kept as values, so each dispatcher is handed back the very listener it was given.
	var chatListener:Dynamic;

	var logListener:Dynamic;

	var overListener:Dynamic;

	var outListener:Dynamic;

	var keyUpListener:Dynamic;

	var deactivateListener:Dynamic;

	override public function init(ctx:Context):Void {
		this.ctx = ctx;
		// Pings never take a click from the game.
		ctx.overlay.mouseEnabled = false;
		ctx.overlay.mouseChildren = false;
		chatListener = onChat;
		logListener = onChatLog;
		overListener = onMouseOver;
		outListener = onMouseOut;
		keyUpListener = onKeyUp;
		deactivateListener = function(_) cancel();
		ctx.onKeyDown(keyDown);
		ctx.onFloorExit(function(_) clear());
		ctx.onTownEnter(clear);
		ctx.core.onObjectReady(objectReady);
		ctx.core.onObjectGone(objectGone);
	}

	override public function ready(ctx:Context):Void {
		facade = ctx.core.facade;
		art = new PingArt(facade);
		var events = facade.eventManager;
		events.addEventListener("CHAT_LOG_EVENT", logListener, false, FIRST);
		events.addEventListener("MouseOverOnActorEvent", overListener);
		events.addEventListener("MouseOutOnActorEvent", outListener);
		var stage = ctx.overlay.stage;
		stage.addEventListener("keyUp", keyUpListener, false, BEFORE_HOST);
		// A key let go while the window is in the background never sends its release.
		stage.addEventListener("deactivate", deactivateListener);
		last = Timer.stamp();
		ctx.overlay.addEventListener("enterFrame", frame);
	}

	override public function dispose():Void {
		if (facade != null) {
			var events = facade.eventManager;
			events.removeEventListener("CHAT_LOG_EVENT", logListener);
			events.removeEventListener("MouseOverOnActorEvent", overListener);
			events.removeEventListener("MouseOutOnActorEvent", outListener);
			for (id in watched.keys())
				events.removeEventListener(INCOMING_CHAT + id, chatListener);
		}
		var stage = ctx == null ? null : ctx.overlay.stage;
		if (stage != null) {
			stage.removeEventListener("keyUp", keyUpListener);
			stage.removeEventListener("deactivate", deactivateListener);
		}
		if (art != null)
			art.destroy();
	}

	/** Each player's lines are watched for pings, the local player's own included. */
	function objectReady(object:GameObject):Void {
		if (facade == null || !Std.isOfType(object, PlayerGameObject))
			return;
		var id = Std.string(object.id);
		if (watched.exists(id))
			return;
		watched.set(id, true);
		facade.eventManager.addEventListener(INCOMING_CHAT + id, chatListener, false, FIRST);
	}

	function objectGone(object:GameObject):Void {
		if (object == hovered)
			hovered = null;
		if (facade == null || !Std.isOfType(object, PlayerGameObject))
			return;
		var id = Std.string(object.id);
		if (watched.remove(id))
			facade.eventManager.removeEventListener(INCOMING_CHAT + id, chatListener);
	}

	/** A ping line from a player: its speech bubble never shows. */
	function onChat(event:ChatEvent):Void {
		if (PingChat.parse(event.message) != null)
			event.stopImmediatePropagation();
	}

	/** A ping line on its way to the chat log: it shows as a ping instead. */
	function onChatLog(event:ChatLogEvent):Void {
		var ping = PingChat.parse(event.chat);
		if (ping == null)
			return;
		event.stopImmediatePropagation();
		show(ping, event.playerName);
	}

	function onMouseOver(event:DBMouseEvent):Void {
		hovered = event.actor;
	}

	function onMouseOut(event:DBMouseEvent):Void {
		if (event.actor == hovered)
			hovered = null;
	}

	function keyDown(key:UInt):Bool {
		if (armed && key == KEY_ESCAPE) {
			cancel();
			return true;
		}
		if (key != KEY_G)
			return false;
		if (armed)
			return true;
		if (!canPing())
			return false;
		var stage = ctx.overlay.stage;
		armed = true;
		armedAt = Timer.stamp();
		wheelX = ctx.overlay.mouseX;
		wheelY = ctx.overlay.mouseY;
		spot = worldNode().globalToLocal(new Point(stage.mouseX, stage.mouseY));
		enemy = pick(spot);
		return true;
	}

	function onKeyUp(event:KeyboardEvent):Void {
		if (!armed || event.keyCode != KEY_G)
			return;
		var kind = wheel != null && wheel.shown ? wheel.selected : centre();
		cancel();
		send(kind);
	}

	function frame(_):Void {
		var now = Timer.stamp();
		var dt = Math.min(now - last, 0.1);
		last = now;
		if (armed && (wheel == null || !wheel.shown) && now - armedAt >= HOLD)
			openWheel();
		if (wheel != null && wheel.shown)
			wheel.update(dt, ctx.overlay.mouseX, ctx.overlay.mouseY);
		if (markers.length == 0)
			return;
		var world = worldNode();
		for (marker in markers.copy()) {
			marker.update(dt, world, ctx.overlay, ctx.viewWidth, ctx.viewHeight);
			if (marker.done)
				remove(marker);
		}
	}

	function canPing():Bool {
		return facade != null && art != null && art.ready && ctx.state.floor != null && localPlayer() != null;
	}

	/** The wheel's centre: an attack on the enemy under the cursor, or the spot. */
	function centre():PingKind {
		return enemy != null ? PingKind.ATTACK : PingKind.LOOK;
	}

	function openWheel():Void {
		if (wheel == null) {
			wheel = new PingWheel(art);
			ctx.overlay.addChild(wheel.root);
		}
		wheel.show(wheelX, wheelY, centre());
	}

	function cancel():Void {
		armed = false;
		if (wheel != null)
			wheel.hide();
	}

	function send(kind:PingKind):Void {
		var player = localPlayer();
		if (player == null || spot == null || !allow(sent, SEND_LIMIT))
			return;
		var x = spot.x;
		var y = spot.y;
		var target = 0;
		var targetName:Null<String> = null;
		if (enemy != null) {
			x = enemy.x;
			y = enemy.y;
			target = Std.int(enemy.id);
			targetName = enemy.name;
		}
		// As if typed in the chat: the game shows it here at once too, which shows the ping.
		player.sendChat(player.screenName + ": " + PingChat.encode(kind, x, y, target, targetName));
	}

	function show(ping:PingChat, sender:String):Void {
		if (art == null || !art.ready || ctx.state.floor == null)
			return;
		var stamps = shownBy.get(sender);
		if (stamps == null) {
			stamps = [];
			shownBy.set(sender, stamps);
		}
		if (!allow(stamps, SHOW_LIMIT))
			return;
		var target:Null<ActorGameObject> = null;
		if (ping.target > 0) {
			var object = facade.gameObjectManager.getReferenceFromId(ping.target);
			if (Std.isOfType(object, ActorGameObject))
				target = cast object;
		}
		var marker = new PingMarker(ping.kind, sender, ping.x, ping.y, target, art);
		markers.push(marker);
		// Under the wheel.
		ctx.overlay.addChildAt(marker.root, 0);
		if (markers.length > MAX_MARKERS)
			remove(markers[0]);
		art.play(ping.kind);
	}

	function remove(marker:PingMarker):Void {
		markers.remove(marker);
		if (marker.root.parent != null)
			marker.root.parent.removeChild(marker.root);
	}

	function clear():Void {
		cancel();
		for (marker in markers.copy())
			remove(marker);
		hovered = null;
	}

	/** The enemy the cursor is on: the one the game reports under it, else the nearest close by. */
	function pick(at:Point):Null<Monster> {
		var floor = ctx.state.floor;
		if (floor == null)
			return null;
		var best:Null<Monster> = null;
		var bestDistance = PICK_RADIUS;
		for (monster in floor.monsters) {
			if (hovered != null && !hovered.isDestroyed && Std.int(monster.id) == Std.int(hovered.id))
				return monster;
			// To its body rather than its feet, where the cursor rests on it.
			var dx = monster.x - at.x;
			var dy = monster.y - 40 - at.y;
			var distance = Math.sqrt(dx * dx + dy * dy);
			if (distance < bestDistance) {
				best = monster;
				bestDistance = distance;
			}
		}
		return best;
	}

	/** The local player's object, which speaks in the chat: its id is the account's. */
	function localPlayer():Null<PlayerGameObjectOwner> {
		var object = facade.gameObjectManager.getReferenceFromId(facade.dbAccountInfo.id);
		return Std.isOfType(object, PlayerGameObjectOwner) ? cast object : null;
	}

	/** The game's world, where a hero's position is its place. */
	function worldNode():DisplayObject {
		return facade.sceneGraphManager.worldTransformNode;
	}

	/** Records an event now, unless `limit` of them already happened in the last `WINDOW` seconds. */
	static function allow(stamps:Array<Float>, limit:Int):Bool {
		var now = Timer.stamp();
		while (stamps.length > 0 && now - stamps[0] > WINDOW)
			stamps.shift();
		if (stamps.length >= limit)
			return false;
		stamps.push(now);
		return true;
	}
}
