# 战斗 UI 美术

使用内置 image_gen 生成；参考图为 `../hangar-battlefield-menu.png`。无文字位图与原生 Godot 控件分离。

- `frontier-pause-v2.png`：当前使用的暂停菜单插画，配合原生半透明炭灰面板、金色细边、开放式列表与原生文字。
- `command-panel-v2.png`、`command-panorama-v1.png`：第一轮探索，现已停用；不再作为背景重复铺设。

## 第二轮最终插画提示词

Use case: stylized-concept
Asset type: portrait 2:3 illustration for the art column of a premium strategy-game pause menu.
Primary request: a sophisticated atmospheric editorial game illustration of an industrial coastal frontier, from the same grounded science-fiction world as the supplied hangar reference. Strong graphic composition and beautifully simplified painterly shapes: monumental charcoal fortress architecture rising on the RIGHT of the image, a small armored convoy on a curving road low in the frame, vast misty mountains receding over a muted warm ivory dawn horizon. A single restrained amber light reflected in the harbor. Elegant architectural silhouettes, atmospheric depth, soft color fields. A collectible art-book plate, modern, composed and quiet.
Input images: supplied image is a setting reference only. Create a distinct new artwork, not a crop of it.
Color palette: ink navy, desaturated slate, warm fog white and a tiny muted gold highlight.
Composition: portrait image, center-left mostly open atmospheric mist, fortress on right, dark lower third. Clean large shapes with selective fine details; no busy clutter.
Constraints: artwork only. No UI, no lettering, no symbols, no frames, no watermark, no grain or distressed texture. No orange neon, no fantasy ornament.

## 面板初始提示词

Use case: stylized-concept
Asset type: production-ready square texture for a native strategy-game UI panel, to be used with nine-slice stretching.
Primary request: one exquisite restrained dark industrial command-console panel surface matching the supplied game's cinematic hangar artwork. This is a usable empty UI background asset, not a UI screenshot.
Input images: Image 1 is a style reference only for materials, lighting and muted palette.
Style/medium: hand-painted premium grounded military science-fiction game UI material, fine charcoal ceramic and dark slate gunmetal with subtle brushed grain, beautifully controlled surface patina.
Composition: a single flat front-facing rectangular surface filling the image edge to edge, no perspective. Very thin recessed machined edges restricted to outermost 3 percent. Small understated chamfer details only at corners. Large 90 percent quiet extremely dark center (#131d22 approx) for perfectly readable live text and controls. Slight warm bronze reflected light near top left edge, restrained cool slate on opposite edge. No bright border.
Lighting: soft ambient, subtle material relief, low contrast, refined rather than distressed.
Constraints: one panel only, no text, no labels, no symbols, no screws in the center, no separate elements, no grids, no controls, no outer drop shadow, no logo, no watermark. Opaque full-bleed square image. Do not depict the reference scene or characters.

## 面板最终精修提示词

Use case: precise-object-edit
Asset type: understated premium science-fiction game interface panel material.
Edit target: the supplied square command panel texture.
Change only the material treatment and framing: remove ALL thick framing, metallic borders, exposed bronze corners, diagonal corner bevels, bright scratches and edge ornaments. Replace them with the same nearly uniform deep charcoal-slate ceramic surface across the ENTIRE image. Edge-to-edge frameless surface, no border of any kind. Preserve the dark slate palette and barely visible finely brushed industrial texture. Center and edges both should be approximately #152126 with extremely low contrast. A very faint diffused warm reflection in the upper left, extremely subdued cool slate in the lower right, no recognizable objects. The image should feel like an exquisite smooth matte black aircraft instrument console, minimal contemporary cinematic game UI, not medieval or distressed. Large quiet area for live typography. Square opaque texture. No text, no UI, no linework, no grid, no vignette frame, no logos.

## 插画最终提示词

Use case: stylized-concept
Asset type: panoramic illustration for the header of an in-game command panel and pause/mission dialog, aspect ratio 3:1.
Primary request: premium cinematic industrial science fiction strategy-game artwork matching the supplied main-menu hangar image. A quiet command operations room overlooking the same immense fortified mountain hangar and armored vehicle staging ground at dawn, composed as an elegant panoramic vignette. A dark machined console in foreground, atmospheric slate mountain fortress and tiny armored silhouettes toward the right half, soft amber light on metal. Restrained, painterly, evocative, detailed but not busy.
Input images: Image 1 is the game's existing main-menu illustration, a style and setting reference, not an edit target.
Composition: very wide horizontal artwork, strongest imagery on the right two thirds, left third is almost-black softly lit negative space for native title text. Horizon near upper third. No human portrait, no giant dominant object. Lower quarter naturally fades into near-black slate shadow. Rich depth and sophisticated lighting, polished game art.
Color palette: charcoal, desaturated slate, a little warm bronze sunlight, pale ivory mist. Avoid saturated neon.
Constraints: image artwork only, no text, no readable signage, no numbers, no emblem, no UI controls, no frame, no watermark.
