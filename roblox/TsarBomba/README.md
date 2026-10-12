# Tsar Bomba (Roblox)

Gives **c00lzerRSolo** a `Tsar Bomba` tool. Equipping it instantly un-equips it and releases an AN602 bomb over a point 380 studs in front of you. The bomb free-falls, opens its parachute and drifts down with a live telemetry billboard. It then air-bursts with a full 50-megaton sequence.

## Option A: paste into the console (live game you own)

1. In-game press **F9** → **Server** tab.
2. Paste the whole contents of `Console/TsarBomba.oneline.lua` into the command bar and press Enter.
3. You get the tool immediately and again on every respawn, for the rest of that server's life.

All visuals run server-side and replicate to everyone. The screen flash and HUD are put into each player's PlayerGui, and the camera shake goes through `Humanoid.CameraOffset`. `Console/TsarBomba.console.lua` is the readable source of the one-liner.

## Option B: install in Studio (smoothest)

| File | Goes in |
| --- | --- |
| `ServerScriptService/TsarBomba.server.lua` | a **Script** in ServerScriptService |
| `StarterPlayerScripts/TsarBombaClient.client.lua` | a **LocalScript** in StarterPlayer › StarterPlayerScripts |

Here the explosion is rendered on each client at full frame rate. This version also adds rotational camera shake and an FOV punch when the blast wave hits.

## What's simulated

- **Double flash.** A brief X-ray flash, a dip while the shock front turns opaque, then the long thermal pulse. It drives the screen, glare billboard and lights.
- **Fireball.** A white-hot core cools from white through yellow, orange and red to soot. It has a churning, mottled surface of 30 boiling blobs, a heat-shimmer shell, fire and ember particles, and shadow-casting light.
- **Shock.** The incident blast front, a ground-reflected Mach-stem front, a condensation (Wilson) dome, and a ground-hugging dust ring that decelerates like a real blast wave.
- **Mushroom cloud.** A rolling toroidal cap with an incandescent underside, a dome, smoke and embers. A stem sucks dust up from the ground, a base surge spreads out, and condensation collars and an ice cap (pileus) form. Colours vary across the billows.
- **Other effects.** Lightning around the fireball in the first seconds, and fallout ash afterwards. The sky goes dark and orange, then recovers.
- **Blast wave arrival.** It reaches each player late, depending on distance. On arrival: shake, layered booms, a blur pulse and wind-blown debris. The HUD counts down to the blast wave.
- **Physical damage.** It moves outward with the visual ring:
  - Inside the fireball, parts and players are vaporised.
  - Further out, parts are scorched and some catch fire.
  - Glass shatters into flying shards.
  - Structures are torn loose and flung.
  - Humanoids inside the lethal radius die.
  - Terrain burns, and sand under the fireball turns to glass (trinitite).

## Tuning

Everything is in the `CONFIG` table at the top of the server/console script. Useful settings:
- `OwnerImmune`: default `true`, so you survive and can watch.
- `DestroyMap`: set to `false` to only scorch the map.
- Radii, `TargetDistance` and `Cooldown`.
- Optional `rbxassetid://` sound IDs. Without them, Roblox's built-in explosion sound is layered for the boom and rumble.

To rebuild the one-liner after editing the readable console source, strip the comments and join the lines with spaces. Any minifier that keeps string literals intact will work.
