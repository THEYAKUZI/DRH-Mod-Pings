# Pings

A mod for [Dungeon Rampage Haxe](https://github.com/Tutez64/Dungeon-Rampage-Haxe): a MOBA-style ping wheel for callouts to your party in a dungeon.

<!-- drh:show -->
Mark spots and enemies for your party, like pings in League of Legends, drawn in the game's own style.

**In a dungeon:**
- **Hold G** to open the ping wheel where your cursor is, move toward a callout, and let go: *Danger*, *On my way*, *Attack*, *Loot*, *Help*, *Wait*, *Group up* or *Secret?*. Esc cancels.
- **Tap G** to ping the spot under your cursor (*Look here!*). On an enemy, it calls an attack on it, and the ping follows that enemy until it dies.

A ping drops onto the floor with its icon, its rings and a sound, and shows who sent it. When it is off screen, the game's own edge marker points to it, as it does for teammates.

**Who sees it:** pings travel through the dungeon's chat. Party members with this mod see the ping, never the chat line. Party members without it read a short callout in the chat instead, such as `Danger! [p:d:1234:-567]`.

You can send up to 4 pings every 4 seconds.
<!-- /drh:show -->

## How it works

- The wheel and the markers are drawn on the mod's overlay. Off-screen markers reuse the game's `UI_widget` from `db_UI_nametag.swf`, and sounds come from the game's `soundEffects.swf`, played as effects so the game's volume applies.
- A ping is sent with the game's own chat send, as a line ending in a tag: `[p:<kind>:<x>:<y>]`, plus `:<enemy id>` for a ping on an enemy. Positions are world coordinates, the same on every player's screen.
- Incoming lines are caught on the game's event bus before the chat log and the speech bubbles see them.

It reaches the game's own classes (chat, camera, actors), so it is an `extends` mod: a DRH update may break it.
