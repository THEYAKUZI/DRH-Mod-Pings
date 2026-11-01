package mods.pings;

import brain.assetRepository.AssetLoadingComponent;
import brain.assetRepository.SwfAsset;
import brain.sound.SoundAsset;
import facade.DBFacade;
import openfl.display.MovieClip;
import openfl.display.Sprite;
import openfl.filters.GlowFilter;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import sound.DBSoundComponent;

/**
 * What the pings take from the game: the round widget it shows teammates off screen with, its comic
 * font (read from that widget's label), and its sounds, played as effects so its volume applies.
 */
class PingArt {
	static inline final NAMETAG_SWF = "Resources/Art2D/UI/db_UI_nametag.swf";

	static inline final SOUND_SWF = "Resources/Audio/soundEffects.swf";

	static inline final TOWN_SWF = "Resources/Art2D/UI/db_UI_town.swf";

	static inline final VOLUME = 0.8;

	/** The game's text outline, as on its nametags. */
	static inline final GLOW = 0x330000;

	/** True once the widget is loaded: nothing shows before. */
	public var ready(get, never):Bool;

	/** True once the town art is loaded too, for the settings. */
	public var townReady(get, never):Bool;

	var town:Null<SwfAsset>;

	var bodyFont:String = "_sans";

	var loader:AssetLoadingComponent;

	var player:DBSoundComponent;

	var widgetType:Dynamic;

	var titleFont:Null<String>;

	var titleEmbedded:Bool = false;

	var sounds:Map<String, SoundAsset> = new Map();

	public function new(facade:DBFacade) {
		loader = new AssetLoadingComponent(facade);
		player = new DBSoundComponent(facade);
		loader.getSwfAsset(DBFacade.buildFullDownloadPath(NAMETAG_SWF), function(asset:SwfAsset) {
			widgetType = asset.getClass("UI_widget");
			var sample = widget();
			var alert = sample == null ? null : sample.getChildByName("AlertText");
			if (Std.isOfType(alert, TextField)) {
				var field:TextField = cast alert;
				titleFont = field.defaultTextFormat.font;
				titleEmbedded = field.embedFonts;
			}
		});
		loader.getSwfAsset(DBFacade.buildFullDownloadPath(TOWN_SWF), function(asset:SwfAsset) {
			var popupType:Dynamic = asset.getClass("popup");
			var sample:MovieClip = popupType == null ? null : cast ASCompat.createInstance(popupType, []);
			var body = sample == null ? null : sample.getChildByName("message_label");
			if (Std.isOfType(body, TextField))
				bodyFont = (cast body : TextField).defaultTextFormat.font;
			town = asset;
		});
		for (kind in PingKind.ALL)
			loadSound(kind);
	}

	function get_ready():Bool {
		return widgetType != null;
	}

	function get_townReady():Bool {
		return town != null && widgetType != null;
	}

	/** The game's town popup: a frame (`popup_base`), a banner and its title, a close button. */
	public function popup():MovieClip {
		return townSymbol("popup");
	}

	/** The game's prompt button: `up`, `over` and `disabled` states, and a `label`. */
	public function button():MovieClip {
		return townSymbol("UI_prompt_button_extended");
	}

	function townSymbol(name:String):MovieClip {
		var type:Dynamic = town.getClass(name);
		return cast ASCompat.createInstance(type, []);
	}

	/** A label in the game's comic font, or else its bold one, to go in `outlined()`. */
	public function text(title:Bool, size:Int, color:Int, width:Float, align:TextFormatAlign):TextField {
		var field = PingArt.label(width, size * 1.7);
		field.embedFonts = titleEmbedded;
		var format = new TextFormat(title ? titleFont : bodyFont, size, color);
		format.align = align;
		field.defaultTextFormat = format;
		return field;
	}

	/** A layer for labels, outlined as the game's popups are: one outline for them all. */
	public static function outlined():Sprite {
		var layer = new Sprite();
		layer.mouseEnabled = false;
		layer.mouseChildren = false;
		layer.filters = [new GlowFilter(GLOW, 1, 4, 4, 4)];
		return layer;
	}

	/**
	 * A new instance of the game's widget: a round frame (`UI_avatar` inside it), a name over it
	 * (`NametagText`), a callout under it (`AlertText`) and an arrow that turns around it (`UI_arrow`).
	 */
	public function widget():Null<MovieClip> {
		return widgetType == null ? null : cast ASCompat.createInstance(widgetType, []);
	}

	/** A label in the game's comic font, centred on its width, outlined as the game's are. */
	public function title(size:Int, color:Int, width:Float):TextField {
		var field = label(width, size + 8);
		field.embedFonts = titleEmbedded;
		field.defaultTextFormat = new TextFormat(titleFont != null ? titleFont : "_sans", size, color, true, null, null, null, null,
			TextFormatAlign.CENTER);
		field.filters = [new GlowFilter(GLOW, 1, 3, 3, 3)];
		return field;
	}

	/** A label as the game's nametags: bold white, outlined, centred on its width. */
	public static function name(width:Float):TextField {
		var field = label(width, 20);
		field.defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF, true, null, null, null, null, TextFormatAlign.CENTER);
		field.filters = [new GlowFilter(GLOW, 1, 3, 3, 4)];
		return field;
	}

	static function label(width:Float, height:Float):TextField {
		var field = new TextField();
		field.selectable = false;
		field.mouseEnabled = false;
		field.width = width;
		field.height = height;
		return field;
	}

	function loadSound(kind:PingKind):Void {
		loader.getSoundAsset(DBFacade.buildFullDownloadPath(SOUND_SWF), kind.sound, function(asset:SoundAsset) sounds.set(kind.code, asset));
	}

	public function play(kind:PingKind):Void {
		var asset = sounds.get(kind.code);
		if (asset != null)
			player.playSfxOneShot(asset, null, 0, VOLUME);
	}

	public function destroy():Void {
		loader.destroy();
		player.destroy();
	}
}
