# Café visits backend

Status: implementation in progress, not deployed or database-tested yet.

Apply `supabase/migrations/202609120001_cafe_social.sql` to a Supabase project. Run `supabase/tests/cafe_social.sql` against a disposable database with SQL errors configured to stop execution. The test rolls back its temporary users and rows. The current workstation has Docker installed, but no running Docker engine; no PostgreSQL or Supabase CLI was found on PATH.

The game will use Supabase Auth and call `POST /rest/v1/rpc/cafe_social` with an authenticated player's bearer token, the project's publishable key, and `{ "action": "...", "payload": {} }`. Never put a service-role key in the game.

Actions:

- `register`: `display_name`; creates/renames the caller's profile and returns its stable code.
- `profile`: own code, name and visit-sharing state.
- `publish`: `layout` containing version 1, theme, table_position and upgrade flags; enables visits.
- `hide`: disables visits immediately, including visits from existing friends.
- `visit`: `code`; returns the last published layout, name, revision and timestamp even when its owner is offline.
- `request`, `accept`, `remove`: `code`; request friendship, accept an incoming request, or cancel/decline/remove either direction.
- `friends`: returns codes and names with incoming/outgoing/friend status.

Private tables have RLS enabled and no client grants. The explicitly granted RPC derives ownership from `auth.uid()`, fixes its search path, and returns friend codes instead of account UUIDs. Publishing constructs an allowlisted layout; inventory, currency, local saves and tokens are excluded. Visits are read-only snapshots and never run sales or crafting on the owner's account.

Still needed: execute the SQL test, Godot authentication/session management and network error handling, friend UI, read-only visitor scene, expanded snapshot cosmetics, hosted project creation and two-account deployment verification. Registration requires the user's own sign-in/email verification.

Design references: [Supabase row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security) and [database functions](https://supabase.com/docs/guides/database/functions).

## Client and visitor implementation

`CafeOnline` now loads the public project URL/key from `online.cfg`, creates an anonymous Auth identity on first online use, persists its refresh session separately from gameplay saves, and refreshes expired sessions. Anonymous Auth must be enabled on the hosted project. Losing device session data currently loses that online identity; account linking/recovery is not implemented yet. The client never silently creates a replacement identity after refresh failure.

The café Friends menu supports profile creation, copying friend code, publishing/hiding, visiting by code, sending/accepting/removing requests and listing friends. Visits render a separate world with validated snapshot geometry, no customers/crafting/collection, and pause the local café until return. `check_online_client.gd` passes simulated transport/session tests; `check_cafe_visit.gd` passes snapshot validation and local-state isolation checks. Neither test proves hosted operation. `check_recipe_discovery.gd` passes after menu integration. Full friend UI interaction and rendered visitor QA remain required.

## Local runtime check, September 14

Attempted `docker desktop start` with approved elevated access. The command stayed pending, no Docker Desktop/backend process appeared, and `docker info` failed because the Linux engine pipe was absent. The pending CLI command was cancelled; no test database was created. SQL migration/test execution is still unverified.

Friend requests now lock both participant profiles in UUID order and cap both lists at 100 relationships, while retries for an existing relationship remain idempotent. The corresponding client error message compiles and `check_online_client.gd` passes. This does not prove database concurrency behavior; that requires the SQL runtime.

## Database verification, September 14

After the user started Docker, PostgreSQL 17 ran in `usr-cafe-db-test-20260914` with no network and no published ports. The local Auth stub, migration, and SQL access tests executed with `ON_ERROR_STOP=1` and exited 0. Verified publishing/visiting, private-field exclusion, denied direct-table access, requestless acceptance rejection, duplicate requests, incoming/outgoing/accepted state, hidden visit rejection, removal and unauthenticated denial. Test data rolled back. This uses a stub of Supabase Auth and does not verify hosted Auth or HTTP transport.

The user supplied project `dscoywqhdwbikthefsll`. The in-app browser redirects its dashboard to sign-in; user login there is needed to deploy. No hosted migration has been applied and no publishable key has been configured.

## Hosted deployment

The project dashboard is now signed in. Applied the café schema and RPC to `dscoywqhdwbikthefsll` through its SQL Editor in one BEGIN/COMMIT transaction. The editor reported `Success. No rows returned`. Query ID: `f5c5df95-af1b-4e22-85f6-89dcd64e6063`. No gameplay/user data was uploaded. Remaining hosted work: enable/configure player authentication, retrieve the publishable key, configure the game and run two-player HTTP/Godot verification. Local PostgreSQL tests are not a substitute for these checks.

## Hosted two-player verification

Anonymous sign-ins were enabled by the user and saved in the dashboard. `online.cfg` contains the project URL and publishable key only. `check_hosted_social.gd -- --live-social-test` ran successfully in Godot against the hosted project using two separate disposable session files (log `D:/UltimateSugarRush/tmp/hosted-live-2.log`, exit 0).

Verified independent friend codes; publishing furniture, theme, display finish and upgrade flags; fetching the layout after the owner's client is freed; successful visitor schema validation; friend request/accept/list; restored owner identity after a new client instance; denial after hiding; and friendship removal. The two QA identities remain for follow-up tests, with the owner cafe hidden and their friendship removed. No real player's save was used. Hosted Godot GUI interactions and broader completion audit remain outstanding.
