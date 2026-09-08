# Game database

The game uses an offline-first, table-style database. Static design content lives in
`res://data/game_database.json`; mutable player records are copied into the versioned
autosave at `user://savegame.json`.

## Tables

| Table | Mutability | Purpose |
|---|---|---|
| `users` | Mutable | Local player identity and timestamps |
| `player_stats` | Mutable | Level, XP, currencies, and lifetime totals |
| `quest_progress` | Mutable | Per-player quest state and objective progress |
| `inventory` | Mutable | Item quantities owned by the player |
| `food_drinks` | Read-only | Recipe catalog for food and drinks |
| `quests` | Read-only | Quest definitions and reward references |
| `items` | Read-only | Ingredients, boosters, and future inventory types |
| `xp_rewards` | Read-only | Reusable XP reward amounts |
| `currency_rewards` | Read-only | Reusable coin or gem reward amounts |

Every record has a stable string `id`. References use an `_id` suffix. IDs should never
be renamed after release; changing display names is safe.

## Runtime API

```gdscript
var lemonade := GameDatabase.get_record(&"food_drinks", "lemonade")
var quests := GameDatabase.get_all(&"quests")
var stats := GameDatabase.get_player_stats()

GameDatabase.update_fields(&"player_stats", "local_player", {
    "orders_completed": int(stats.orders_completed) + 1
})
GameDatabase.grant_xp("xp_small")
GameDatabase.grant_currency("coins_small")
```

Only mutable tables accept `upsert_record` or `update_fields`. Every mutation schedules
an autosave automatically.
