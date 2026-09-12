# Landscape café and boards

The project uses a 1920 × 1080 landscape canvas, with a 960 × 540 desktop preview. The café floor and surrounding neighborhood spread 1.5 times farther in both ground-plane directions. Furniture and characters retain their size, leaving wider aisles.

All five merge scenes use a 10 × 6 grid. Old 6 × 8 saves map each item's linear slot into the new grid, preserving identity and frozen state. Match-three grids remain 8 × 8. Both layouts place objective cards vertically on the right. Candy collection animations resolve their destinations from the current objective controls' global positions.

The three landscape maps use separate painted routes. Sugar Blossom follows a gentle orchard path; Honeydew reverses direction up tea terraces; Cocoa climbs a bridge route. Stage positions are sampled from their respective artwork. The original eight boards and regional challenge progression remain connected.

## Café flow

Tap the bread oven, coffee machine, candy station, cake oven, or tea brewer to open its recipe. The bottom recipe categories and Quests show ingredients and direct players to a machine; they cannot start crafting.

Starting a recipe consumes ingredients once and saves a completion timestamp. Jobs continue while the café is closed. Crafting takes 10–20 seconds depending on the recipe. A finished job shows a floating product icon; tapping it transfers the entire batch into the corresponding display inventory and awards 20 XP. Uncollected jobs cannot be purchased or restarted.

Customers choose available displayed products, walk to the matching case, and buy one item at its listed price. Existing product inventory is treated as displayed stock for save compatibility. Tea currently uses the latte atlas icon.

## Verification

- `tests/check_landscape_boards.gd`: nine scene layouts, board bounds, objective bounds and live collection targets.
- `tests/check_merge_migration.gd`: all 48 old slots, item identities, frozen flags, save and reload.
- `tests/check_machine_jobs.gd`: all five recipes, ingredient consumption, busy-machine rejection, persistence, collection and individual purchases.
- `tests/check_cafe_machine_flow.gd`: recipe menu restrictions, actual craft button, ready icon, full-batch collection and purchase at the matching display.
- `tests/check_customer_visits.gd`: repeated customer visits, display clearance and minimum customer separation.
- `tests/check_machine_input.gd`: projected machine taps and floating-icon collection through the world input handler for all five stations.
- `tests/render_landscape.gd` and `tests/render_landscape_cafe_details.gd`: maps, boards, café, recipe book, rewards and four maximum-zoom pan extremes.

Run tests using a disposable APPDATA/LOCALAPPDATA directory to protect player saves. Android export has not been verified in this environment. The opening screen was rendered at 960 × 540 with its continue button visible and in bounds. A five-minute simulation confirmed repeated purchases by both customers, no display intersections, and a minimum separation of 0.575 world units after separating the exit lane.
