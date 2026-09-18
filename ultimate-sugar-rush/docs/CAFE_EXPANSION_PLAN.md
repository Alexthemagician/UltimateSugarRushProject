# Café expansion — implementation and verification

## Scope delivered

| Requested feature | Implemented behavior | Evidence |
| --- | --- | --- |
| Regular customers and stories | Mint prefers tea, Berry cake, Coco candy. Each visit randomly chooses an unlocked recipe in that category. Matching purchases advance saved friendship and stories. Regulars page shows preferences, story and discovery progress. | check_recipe_discovery; check_customer_visits; regulars_page.png |
| Recipe variety | Ten recipes, two per existing category: bakery, coffee, candy, cake, tea. Five machines each support two recipes with one active job. Variants have distinct 3D toppings/colors. | check_machine_jobs; check_machine_input; recipe_models.png |
| Visible upgrades | Efficient ovens reduce baking time; showcase adds gold lighting and one sale coin; garden and terrace seating add visible furnishings. Purchases and ownership persist. | check_cafe_upgrades |
| Special orders | Three sequential character orders consume reserved pantry products and award coins/XP once. Insufficient stock and duplicate deliveries are rejected. | check_special_orders |
| Decorating | Move the table/chair group in the seating area; save three floor/wall palettes and three display finishes. Entrance and display aisles remain protected. | check_furniture_placement; check_decor_themes; check_shared_display |
| Recipe discovery | Board wins unlock caramel buns/mocha; three happy visits unlock character recipes. Locked silhouettes and hints appear in recipes and Regulars. | check_recipe_discovery; regulars_page.png |
| Café events | Three themes rotate every three completed boards. Relevant category sales earn extra coins. No calendar or missed-day penalty. Menus show actual sale prices including bonuses. | check_cafe_events; check_quest_gui |
| Online friends and visits | Supabase anonymous identities; friend codes, requests, accept/remove; publish/hide café; read-only hosted visits even after owner client closes. Returning resumes local café. | check_hosted_social; check_hosted_gui; check_cafe_visit; check_visit_return |

Tests are in `tests/`. Relevant final logs and rendered evidence are in `D:/UltimateSugarRush/tmp/`. The latest hosted checks are `hosted-showcase.log` and `hosted-gui.log`, both with zero failures. Final sale-price checks are `price-final-check_cafe_upgrades.log`, `price-final-check_cafe_events.log`, and `price-final-check_recipe_discovery.log`, all passing. Customer simulation covers five minutes, all three regulars, repeated purchases, minimum separation 0.563 and zero display-case intersections.

## Hosted service

Project: `dscoywqhdwbikthefsll`. Both SQL migrations are deployed. Anonymous sign-ins are enabled with the user's approval. The game includes only the project URL and publishable key; session tokens are stored separately in the device's user directory and never included in shared layouts. Private database tables have RLS and no client grants. The RPC derives ownership from Auth, allowlists snapshot fields and caps friend relationships. SQL checks passed locally using PostgreSQL 17 with a Supabase Auth contract stub; real hosted Godot tests verified two separate Auth identities and HTTP operations.

Two QA identities remain for repeatable tests. Their café sharing is closed and their friendship removed after tests. Real gameplay saves were not used.

## How to play

Use Regulars for stories and rewards, Upgrades for purchases, Special orders to deliver pantry stock, and Decorate for the seating group and finishes. Craft at a machine and collect its batch; store display stock for later orders. Friends lets you create a public café name, copy your code, publish your décor, request friends and visit by code. Publish again after decorating to update the saved visitor view.

## Practical limits

- Visits display the last published décor; they are not simultaneous live multiplayer. Visitors do not trade, buy stock or alter the owner's save.
- Anonymous identity is device-local. Uninstalling/removing its session file loses that online identity; account linking/cross-device recovery is not included.
- Recipe categories currently cover bakery, coffee, candy, cake and tea. Cupcake was an example category in the request, not a separate implemented machine.
- Android export includes `online.cfg` and Internet permission. A resource-pack export completed and contains the config. APK/device validation remains unperformed because Android SDK tools are unavailable; desktop Godot gameplay and live hosting were tested.
