# Dota radar assets

Prepared 29 October 2026. No game files were modified and no active game UI was controlled.

## Recommended map

`dota-map.webp` is a local copy decoded from the active map material in the user's installed Dota client. It is 512×512. Use the WebP for the site; PNG is included for inspection. Do **not** choose `dota-map-unused-psd.webp` by resolution alone: it has different padding and is not the texture referenced by the active overview material.

Verified material chain:

1. `resource/overviews/dota.txt` names `materials/overviews/dota.vmat`.
2. That material's RERL block references `materials/overviews/dota_tga_d8178876.vtex`.
3. The compiled VTEX DATA header says 512×512, RGBA8888, one mip. Its exact 1,048,576-byte RGBA payload was decoded without rescaling or retouching.

The installed `steam.inf` identifies ClientVersion/ServerVersion 6969, SourceRevision 11175759, VersionDate Oct 27 2026. This establishes the installed asset's age; it is not a promise that the latest Steam update has been installed.

## Coordinates

The same Valve overview metadata gives `pos_x -9472`, `pos_y 9472`, `scale 18.500`. Overview coordinates use a 1024px reference space independently of the source texture's 512px resolution. For the active 512px map:

```text
u = (worldX + 9472) / 18944
v = (9472 - worldY) / 18944
pixelX = u * 512
pixelY = v * 512
```

Use Y inversion: positive world Y is upward, positive image Y downward. Center (0,0) maps to (256,256). The top-left overview corner (-9472,9472) maps to (0,0); the opposite corner maps to (512,512). A viewport crop/zoom should be applied to both image and markers using the same transform.

The old third-party page used an image half-span of 10240 and viewport half-span of 9100. Those values belong to its own image treatment and should not be blindly reused with this active native asset.

The metadata, material references, header dimensions and transformation arithmetic are verified. A live in-game landmark alignment test remains appropriate before claiming pixel-perfect calibration. The unused padded 1024px PSD is not a drop-in calibrated substitute.

## Hero and item art

26 sample/demo images are downloaded into `heroes/`, `items/` and `abilities/`, with exact URLs and SHA-256 values in `cdn_manifest.json`. The source is Valve's public Steam CDN:

```text
https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/<hero-key>.png
https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/items/<item-key-without-item_-prefix>.png
https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/abilities/<ability-name>.png
```

The three patterns were fetched and decoded successfully for those samples; every possible ability or internal item name was not exhaustively verified. Hero identifiers preserve Valve's internal aliases, for example `windrunner`, `nevermore`, `antimage`. A full live app can use these official CDN routes with local cached fallbacks, or fetch an expanded known asset set at build time; it need not request assets from the old radar owner's domain.

## Official name metadata

`heroes.json` contains 127 public heroes from Valve's own `https://www.dota2.com/datafeed/herolist?language=english` and corresponding Russian feed, fetched successfully on 2026-10-29. Entries are indexed by the exact `npc_dota_hero_*` identifier emitted by Lua, and include internal asset key, numeric ID, English/Russian display names, primary attribute and portrait URL. The raw responses are retained as `valve-heroes-en.json` and `valve-heroes-ru.json`.

`items.json` similarly contains 544 item records from `https://www.dota2.com/datafeed/itemlist?language=english`; these include historical/internal entries, so do not assume all 544 can occur in a normal current match or that every generated CDN URL exists. The names are factual metadata; image copyrights remain Valve's.

## Sources and rights

- Map source: the user's local Valve Dota 2 install, `pak01_dir.vpk`, active overview path above. `native_manifest.json` records extracted entries and hashes.
- Pixel-format/header interpretation was checked against the primary ValveResourceFormat implementation: https://github.com/ValveResourceFormat/ValveResourceFormat/blob/master/ValveResourceFormat/Resource/Enums/VTexFormat.cs and https://github.com/ValveResourceFormat/ValveResourceFormat/blob/master/ValveResourceFormat/Resource/ResourceTypes/Texture.cs . Only our small extraction/decoding helpers are included; no VRF source was copied into the application.
- Dota 2 artwork, map, hero names and trademarks belong to Valve Corporation. These game assets are **not** covered by a permissive license merely because a CDN or local game install makes them readable. Keep Valve attribution and avoid claiming ownership. If public redistribution must be licensed, that remains a separate verification; extraction is not proof of redistribution permission.
- The official New Frontiers page (https://www.dota2.com/newfrontiers) contains a 7.33-era promotional map, so it should not be presented as a current calibrated game map.

No old-site HTML/CSS/JS or old-owner image was copied into these prepared map and demo assets.
