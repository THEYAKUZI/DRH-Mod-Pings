package mods.pings;

import actor.ActorGameObject;
import actor.player.input.dBMouseEvents.DBMouseEvent;
import brain.gameObject.GameObject;
import brain.uI.UIButton;
import dBGlobals.DBGlobal;
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
import openfl.display.MovieClip;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.geom.Point;

/**
 * Pings for callouts in a dungeon, as in MOBAs. Hold the ping key (G unless changed) for the wheel
 * and let go on a callout, which becomes the quick ping; tap it to send the quick ping, by default
 * the spot under the cursor, or an attack on the enemy there. Its settings open from the game's options.
 *
 * A ping travels as a chat line, through the game's own chat. The party's players with this mod see
 * it on the floor, with a sound, and never the line; the others read the line, a plain callout.
 */
class Main extends Mod {
	static inline final KEY_ESCAPE:UInt = 27;

	/** The layer of the game's popups, where its options panel shows. */
	static inline final POPUP_LAYER = 105;

	/** Names the button the mod adds to the game's options panel, which it adds once. */
	static inline final OPTIONS_BUTTON = "pings_settings_button";

	/** How much taller the options panel gets for that button, in its own units. */
	static inline final OPTIONS_EXTRA = 40.0;

	static inline final OPTIONS_BUTTON_SCALE = 0.85;

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

	var settings:PingSettings;

	var settingsPopup:Null<PingSettingsPopup>;

	/** The buttons added to the game's options panels. */
	var optionsButtons:Array<UIButton> = [];

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

	var popupListener:Dynamic;

	override public function init(ctx:Context):Void {
		this.ctx = ctx;
		settings = new PingSettings(ctx.data, ctx.log);
		popupListener = onPopupAdded;
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
		facade.sceneGraphManager.getLayer(POPUP_LAYER).addEventListener("added", popupListener);
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
			facade.sceneGraphManager.getLayer(POPUP_LAYER).removeEventListener("added", popupListener);
		}
		if (settingsPopup != null)
			settingsPopup.close();
		for (button in optionsButtons)
			button.destroy();
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
		if (settingsPopup != null) {
			var code:Int = key;
			if (settingsPopup.keyPressed(code))
				return true;
			if (key == KEY_ESCAPE) {
				settingsPopup.close();
				return true;
			}
		}
		if (armed && key == KEY_ESCAPE) {
			cancel();
			return true;
		}
		if (key != pingKey())
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
		if (!armed || event.keyCode != pingKey())
			return;
		var kind = quick();
		if (wheel != null && wheel.shown) {
			// The callout picked becomes the quick ping; the centre goes back to the spot.
			kind = wheel.selected;
			settings.quick = wheel.onCentre ? null : kind;
			settings.save();
		}
		cancel();
		send(kind);
	}

	function pingKey():UInt {
		return settings.key;
	}

	function frame(_):Void {
		var now = Timer.stamp();
		var dt = Math.min(now - last, 0.1);
		last = now;
		if (armed && (wheel == null || !wheel.shown) && now - armedAt >= settings.hold())
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

	/** What a tap sends: the callout last picked on the wheel, else the centre's. */
	function quick():PingKind {
		return settings.quick != null ? settings.quick : centre();
	}

	function openWheel():Void {
		if (wheel == null) {
			wheel = new PingWheel(art);
			ctx.overlay.addChild(wheel.root);
		}
		wheel.show(wheelX, wheelY, centre(), settings.quick);
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
		// The other players' pings can be hidden; their lines stay out of the chat all the same.
		var player = localPlayer();
		if (!settings.others && (player == null || sender != player.screenName))
			return;
		var target:Null<ActorGameObject> = null;
		if (ping.target > 0) {
			var object = facade.gameObjectManager.getReferenceFromId(ping.target);
			if (Std.isOfType(object, ActorGameObject))
				target = cast object;
		}
		var marker = new PingMarker(ping.kind, sender, ping.x, ping.y, target, art, settings.scale());
		markers.push(marker);
		// Under the wheel.
		ctx.overlay.addChildAt(marker.root, 0);
		if (markers.length > MAX_MARKERS)
			remove(markers[0]);
		if (settings.sounds)
			art.play(ping.kind);
	}

	/**
	 * The game's options panel, in town or in a dungeon, when it shows: once, it gets a little taller
	 * and a PINGS button at its bottom, which opens the ping settings.
	 */
	function onPopupAdded(event:Event):Void {
		if (!Std.isOfType(event.target, MovieClip) || art == null || !art.townReady)
			return;
		var panel:MovieClip = cast event.target;
		if (panel.getChildByName("music_slider") == null || panel.getChildByName("hud_label") == null
			|| panel.getChildByName(OPTIONS_BUTTON) != null)
			return;
		// Its frame is its first child, stretched from its top down.
		var frame = panel.getChildAt(0);
		var before = frame.getBounds(panel);
		var own = frame.getBounds(frame);
		frame.scaleY = frame.scaleY * (before.height + OPTIONS_EXTRA) / before.height;
		frame.y = before.top - own.top * frame.scaleY;
		var clip = art.button();
		clip.name = OPTIONS_BUTTON;
		clip.scaleX = clip.scaleY = OPTIONS_BUTTON_SCALE;
		clip.x = before.left + before.width / 2;
		clip.y = before.bottom + OPTIONS_EXTRA / 2 - 6;
		panel.addChild(clip);
		var button = new UIButton(facade, clip);
		button.label.text = "PINGS";
		button.rolloverFilter = DBGlobal.UI_ROLLOVER_FILTER;
		button.releaseCallback = openSettings;
		optionsButtons.push(button);
	}

	function openSettings():Void {
		if (settingsPopup != null || facade == null || art == null)
			return;
		settingsPopup = new PingSettingsPopup(facade, art, settings, settingsClosed);
	}

	function settingsClosed():Void {
		settingsPopup = null;
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
