# Quest journal and batch collection

Quests opens a dedicated lavender journal with six clickable tabs on the left. The first quest opens by default. Each view includes an action, a large item image (or a static XP bar), progress, a description and an ingredient or crafting tip. Categories cover buns, sales coins, XP, beverages, cakes and bonbons.

Quest progress is saved in `quest_progress`: collected product quantities advance crafting goals, board rewards and batch collection advance XP, and customer purchases advance sales coins. Progress starts when these counters are introduced; existing wallet balances are not treated as new sales.

Ready-batch icons have GUI buttons that track their projected screen positions. This avoids relying solely on unhandled 3D input after the viewport container has consumed the event. Collection transfers the whole batch to the corresponding display and shows a confirmation. Recipe menus remain separate from Quests.

Menu palettes: golden recipe book, mint pantry, blue map selection, lavender collection gallery and neutral settings.

`tests/check_quest_gui.gd` injects real mouse events through `Input.parse_input_event` at a 960 × 540 window. It verifies all five batch collections, display visibility, a customer purchase, wallet and quest updates, persistence, all six quest tabs, the default first view and distinct menu palettes. It renders each quest and menu for visual inspection. The test passed with zero failures using a disposable save profile.
