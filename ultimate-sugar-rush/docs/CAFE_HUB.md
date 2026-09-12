# Café hub and ingredient rewards

The main game's boot screen now opens `res://scenes/cafe/cafe_hub.tscn`. This is the integrated 3D café, not the standalone prototype. The original 2D board mechanics remain in their existing scenes.

## Player flow

- Explore maps opens the original Sugar Blossom map, Honeydew Gardens, or Cocoa Moon.
- The two new maps each have six playable match stages, with increasing targets, lock formations, and (in later Cocoa Moon stages) shifting rows. Completing a stage opens the next. Replays start a fresh attempt.
- Board completion grants the existing collectible reward plus coins, XP, and three ingredient stacks. All 18 requested ingredients are in regional reward pools. Rewards rotate through each pool so all ingredients can be found.
- The café displays the shared GameDatabase wallet/XP. Pantry counts use saved inventory records. Recipes consume ingredients and produce a batch of finished products plus 20 XP; coins are credited when customers purchase individual products.
- Collections and persistent music, sound, and notification preferences are accessible in the café footer. The original map's former settings control now returns to the café. Notification scheduling is still not implemented; the saved preference is labeled accordingly.
- Chef Mallow works between stations. Two chibi customers enter, purchase available finished products, collect a matching treat, exit through the doorway and disappear down the road before returning. Purchases consume finished product stock, never raw ingredients.

## Rendering

The 3D materials use low roughness, clearcoat, cartoon highlights and restrained trim reflections. The camera angle remains fixed. Desktop uses Forward+; Android is configured for Godot's Mobile renderer. Android device performance/export has not been verified. No APK was rebuilt as part of this change.

## Persistence and testing

`CafeProgress` extends the existing SaveSystem and GameDatabase. It does not replace existing saves. Per-attempt receipt IDs prevent duplicate completion callbacks from paying twice. Rewards, recipe consumption, level, wallet and ingredient quantities are persisted through the existing save mechanism.

Run `godot --headless --path ultimate-sugar-rush --script tests/check_cafe.gd` with APPDATA and LOCALAPPDATA redirected to a **new disposable directory**. This test grants rewards and consumes test inventory; never run it against a real player profile. It covers the 18-ingredient catalog, exact economy deltas, duplicate claims, recipe consumption/refusal, persistence, twelve stage configurations, walking/pickup loops, fixed camera, menus, actual scene routing, original-map return, and full completion-to-café flow.

`tests/render_cafe.gd` creates visual previews under the workspace `tmp` folder. `tools/check_match_animations.gd` remains the regression check for the previous match animation changes.

## Generated map artwork

Built-in imagegen was used with `assets/map/sugar_world_anime_map.png` as a **style reference**, not as an edit target. Final assets:
- `assets/map/honeydew_gardens.png`
- `assets/map/cocoa_moon.png`

Prompts:

Honeydew Gardens: Use reference only for painterly anime game-map style and portrait composition. Create a NEW full bleed portrait 9:16 game map background for Honeydew Gardens: lush mint tea gardens, edible flower meadows, little honey-pot cottages, a sparkling spring stream and a charming glass tea conservatory on the hill at the top. Golden honey and sage green with pink flowers, polished hand-painted anime background art at the same quality as reference. An unobstructed winding cream path travels from bottom center through six spacious bends to the top conservatory. Detailed environment, warm magical sunlight. NO text, numbers, interface, icons, markers, or borders. No castle or snow mountains.

Cocoa Moon: Use reference only for polished painterly anime game-map style and tall portrait composition. Create NEW full bleed portrait 9:16 map background for Cocoa Moon: enchanting purple-blue twilight chocolate valley, cocoa bean trees and chocolate truffle cottages with warm windows, little caramel streams, stars, floating cream clouds, crescent moon, and a chocolate patisserie palace on the upper hill. Rose frosting roofs and glowing honey-gold details. A clear winding cream path travels bottom center to top through six spacious bends for later game level placement. Rich hand-painted anime illustration, inviting and magical, same detail quality as reference. NO text, numbers, icons, buttons, interface, stage markers or borders. No green daytime landscape. Keep lower and middle path readable.


## September 9 café polish and navigation update

The main hub now uses an illustrated 5×2 icon atlas (`assets/cafe/menu_atlas.png`): bakery, coffee, candy, cakes, maps, pantry, collection, settings, quests, coin. Captions remain below the nine menu icons. The bordered header holds the café name, a live 3D copy of Chef Mallow with a fixed head pose, blinking and a static closed smile, a subtle level/XP bar, and an icon with the existing numeric coin balance. The portrait uses its own viewport and lighting.

Recipes are in the left quest modal. Each recipe shows current/required ingredient quantities, the region that supplies each ingredient, and batch output, unit sale price, finished stock and the 20-XP crafting reward. Station buttons open their corresponding recipe, with a route back to all recipes. The persistent recipe card has been removed.

The camera retains its fixed angle and supports bounded panning. Orthographic size is clamped to 10.5–22.0 (default 16): plus/minus controls, mouse wheel, trackpad magnify, and two-finger touch pinch use the same bounds. A pinch does not activate a station. The left wall has a genuine opening from z=2.05 to 3.55 under the y=2.7 lintel, with trim and exterior steps. The outdoor neighborhood adds ground, sidewalks, roads, three small buildings and five trees.

Regional ingredient pools remain exclusive. Each region now maintains its own reward rotation, so alternating maps cannot skip half a region's ingredients. The maps menu and regional map footer list their ingredients; recipes also identify ingredient sources.

Materials use roughness 0.12, smooth GGX specular highlights and a stronger clear coat (0.85, roughness 0.08), keeping toon diffuse shading. The standalone prototype shares this material polish, while the new UI/world features live in the main game.

Atlas generation brief: ten equally spaced tiles in a 5×2 sheet; glossy hand-painted patisserie icons in pink, mint, cream and gold; croissant, latte, wrapped candy/lollipop, strawberry cake, folded map, flour/eggs/sugar, collection scrapbook, gear, recipe scroll, star coin; no text. Generated source is preserved in the Codex generated-images directory. The atlas is sampled with clipped AtlasTexture regions; no image processing was used.

Validation: `tests/check_cafe.gd` exercises regional reward exclusivity with interleaved visits, wallet deltas, persistence, recipes, map routing, NPC animation, portrait blink/fixed head pose, icon bounds, zoom controls and gesture bounds. `tests/render_cafe.gd` renders the hub, zoom extremes, portrait expression and all modals/maps. Screenshots and logs are under the repository's `tmp` directory. Tests use disposable APPDATA/LOCALAPPDATA profiles. Desktop rendering was inspected at 540×960; physical Android touch/performance remains untested.

See `CAFE_REPLAYABILITY_PLAN.md` for the planning-only economy discussion. No energy, daily gate, ads, premium cash or purchasing code has been added.


## Chibi customers, batch inventory and illustrated item menus

The expanded neighborhood places buildings on grass lots and points each entrance toward its nearest street. The old isolated house arrangement has been replaced by the populated street grid described below.

Characters use rounded short bodies, oversized faces, layered colored eyes with highlights, blush, curved smiles, sculpted fringes and soft hair locks. Walking uses distance-driven planted/swing foot phases and articulated hip/knee segments, with eased speed and turning. The header duplicates the restyled chef in a separate viewport; its head transform stays fixed while only the eyes blink.

| Product | Batch output | Unit sale price |
| --- | ---: | ---: |
| Butter-cloud buns | 50 | 4 coins |
| Vanilla café latte | 20 | 9 coins |
| Petal bonbons | 30 | 6 coins |
| Strawberry celebration cake | 12 | 18 coins |

Crafting consumes the listed raw ingredients and grants 20 XP. It does not grant sale coins up front. Products use persisted `inventory` records named `product_<recipe id>`. A successful customer purchase decrements one item, credits exactly its configured price to the existing wallet, increments completed orders and saves. Unstocked items cannot be bought. Customers select available stock, pause to collect a matching miniature product, follow the doorway and steps to the roadside, and disappear at z=12.5 before respawning after a short interval. If nothing is stocked, they wait briefly and leave empty-handed. There are no offline sales.

The quest and pantry menus show finished stock and sale prices. Sales update the header and any visible stock labels. Map selection uses landscape crops of each existing map illustration. All four recipes and all eighteen ingredients use `assets/cafe/stock_atlas.png`; images appear in recipes, pantry, map ingredient lists, and regional map footers. The atlas uses the menu's cream background. Exact generation prompts are in `CAFE_STOCK_ART.md`.

Validation added in `tests/check_cafe_shop.gd`: exact batch quantities, sale amounts, stock consumption, save/load, sold-out rejection, house placement/rotation, static portrait head and closed smile, complete menu-image coverage, all three thumbnails, bounded movement steps, customer purchase/doorway/down-road disappearance, and wallet updates. Both this suite and `tests/check_cafe.gd` pass. `tests/render_cafe_customers.gd` renders the customer cycle plus the top and bottom of illustrated menus. Test profiles are disposable and do not modify the player's real save.


## Character motion and camera exploration refinement

Chef shoulders are lower and level, with narrower sleeves and relaxed arms at rest. The rounded placeholder hairstyles have been restored pending replacement with custom models. The portrait retains its fixed head pose and blink loop, with a pronounced closed-mouth smile that does not move.

Movement runs at a target 0.72 world units per second, easing into turns. The gait advances only with measured travel distance: one complete two-foot cycle covers 0.80 units. During stance, the foot retreats locally at the body's travel speed, keeping its world position planted; the swing foot follows a lifted return arc. Two articulated segments connect each hip to its shoe through a knee. Stops relax the pose without advancing gait. Shoe height and stair route heights match the floor/steps instead of hovering above them.

Arrivals start farther from the camera along the roadside (initial customers start at staggered negative-z positions; subsequent visits start at z=-17), turn into the left doorway and shop. Departures use the doorway and continue toward the foreground at z=12.5, then disappear. They no longer approach and leave from the same end of the road.

Drag the café view with the left or middle mouse button, or one finger, to pan. Two fingers combine panning with pinch zoom. Drags exceeding six pixels do not select stations. Pan is clamped to ±6 world units on both ground axes, and never changes the camera basis. The Home button restores the default center and zoom. Zoom remains clamped to 10.5–22.

A 100×100 ground plane and extended street/sidewalk grid cover the whole allowed view. Grass lots hold houses in three heights and varied widths, five wall palettes, flat or gabled roofs, windows, door paths and occasional striped shop awnings. Trees vary in size, with round green crowns, pink blossoms and conifers. Six gardens include benches, flowers and cats or rabbits. Tree placement avoids building footprints. Every building's front points at its nearest road.

`tests/check_neighborhood.gd` checks planted-foot motion, gait distance, knee lengths, shoulder level, fixed portrait pose, arrival/departure direction, mouse/touch panning, pan/zoom reset, unchanged camera basis, building orientation and variation. It ray-tests the four screen corners at all nine center/edge/corner pan positions at maximum zoom against the ground and checks nearby population. `tests/render_neighborhood.gd` provides desktop renders at maximum zoom and all four pan corners, plus a close character lineup for visual inspection. Shop/economy and café regression checks also pass. Physical mobile gesture/performance testing remains outstanding.


## September 10: clothing clearance, static smile, reward icons and map consistency

Knee motion is constrained to local y ≤ 0.16 and z between −0.13 and 0.13. The knee and shin surfaces, including their ink outlines, remain below the skirt's bottom edge through the full stride. The upper segment meets the hip inside the garment silhouette. The distance-driven foot motion and planted-foot behavior are retained. Rounded hair locks/fringes have been restored on all three characters for use until custom replacement models are available.

The portrait mouth uses a pronounced closed curved line, with no mouth transform or geometry animation. Only the eye blink remains animated; the head remains still.

The shared board-completion overlay now displays the collectible image, coin icon with exact amount, an XP star with exact XP, and the matching ingredient image beside each ingredient name and quantity. It uses the same ingredient/menu atlases as the café, plus the small native vector `assets/cafe/xp_star.svg`. The reward panel stays visible for two seconds after its reveal before the existing collection transition. Every board type uses this shared completion path; reward accounting is unchanged.

Sugar Blossom's scene now uses the same map renderer as Honeydew Gardens and Cocoa Moon: identical header, Café back-button position, stage button dimensions/styles, caption treatment and ingredient footer. Its eight original boards and saved unlock rules are preserved, including existing development access to stages 5–8. Stage spacing avoids caption/button overlap. Cookie-objective unlock reconciliation is retained. The original world-map scene path remains valid for every board's back navigation.

Validation: `tests/check_visual_refinements.gd` checks garment clearance over 120 stride poses for all three characters, fixed closed mouth geometry, restored hair, all map control positions/styles/counts/unlock gates, stage spacing, and icon/amount coverage across all eighteen possible ingredient rewards. `tests/check_sugar_map_routes.gd` launches each of the eight original boards through its actual button and returns through its Back button. Café, shop and neighborhood regression suites pass. `tests/render_rewards_maps.gd` produces the three map previews, reward popup, and close clothing-clearance poses under `tmp`. All checks use disposable profiles; physical Android testing remains outstanding.
