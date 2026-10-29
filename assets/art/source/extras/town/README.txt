FREE ISOMETRIC PIXEL TOWN SAMPLER - by Antahonist
=================================================

20 free sprites from five isometric pixel-art towns: 2 buildings and 2 props from each of
Neon City (cyberpunk), Soviet City, Spooky Town (Halloween), Arcane Quarter (magic town) and Edo Town (feudal Japan).
All five towns share one scale and one grid, so they mix in the same world.

WHAT'S IN THE BOX
-----------------
sprites_192/   large size: 14 m = 192 px (one 3.3 m grid cell = 64 x 32 px diamond)
sprites_96/    small size: half of that
  buildings/ and props/, each with:
    day/       static day sprite with its shadow
    night/     static night sprite, windows lit
    anim/      night loop strip: 16 frames side by side, 120 ms each (living lights: windows go dark and light up)
    lightson/  dusk-to-night strip: 12 frames, play once, then switch to anim/
    (anim/ and lightson/ exist only for sprites that have lights)
manifest_192.json, manifest_96.json   size and foot pivot of every sprite (+ the town it comes from)
preview/       the store images

PLACING
-------
Place every sprite by its foot pivot (the centre of the building on the ground) and sort by the foot's screen y.
World metres to screen pixels (large size): a point (x, z) sits at cell (i, j) = (x / 3.30, -z / 3.30), screen
(32 * (i + j), 16 * (i - j)).

GET THE FULL TOWNS
------------------
Neon City        https://antahonist.itch.io/neon-city-cyberpunk-pixel-building-kit
Soviet City      https://antahonist.itch.io/soviet-city-isometric-pixel-buildings
Spooky Town      https://antahonist.itch.io/spooky-town-draculas-castle-pixel-buildings
Arcane Quarter   https://antahonist.itch.io/arcane-quarter-magic-town-pixel-buildings
Edo Town         https://antahonist.itch.io/edo-town-feudal-japan-pixel-buildings
All five in one bundle: Pixel City Builders Bundle - https://itch.io/s/204451/pixel-city-builders-bundle
Every full pack also has the RPG 3/4 front view (64 / 32 px grid) and a Godot 4 demo town.

LICENSE
-------
Free for unlimited commercial and non-commercial games. Do not resell or redistribute the sprites on their own.
Credit appreciated: "Town sprites by Antahonist".
Rendered with the 3d-pixel-engine toon pipeline by Egor Novikov (github.com/ijwwsq/3d-pixel-engine, MIT).
The generator code was written with AI assistance; no image AI drew any sprite.
If the sampler helped you, a rating on the itch.io page helps a lot.
