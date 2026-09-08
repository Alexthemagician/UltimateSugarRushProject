# iHeartWorld database recovery

`iheartworld_database_recovery.sql` reconstructs the six-table MySQL schema from
the surviving Java entities, frontend usage, UML, and original starting script.

## Import with MySQL Workbench

1. Connect to the intended MySQL 8 server.
2. Open `iheartworld_database_recovery.sql` in Workbench.
3. Confirm that the connection points to the correct server.
4. Execute the complete script.
5. Confirm that the final query returns six table names.
6. Refresh the **Schemas** panel and expand `i-heart-world`.

The script creates missing objects but does not drop the database or overwrite
existing tables. Back up any surviving database before changing it.

## Important reconstruction details

- The schema name remains `i-heart-world`, matching the Spring datasource URL.
- The table name ``group`` is escaped because `GROUP` is a SQL keyword.
- Both post entities declare their primary key as `id` and their owning User
  relationship as `post_id`. That confusing historical mapping is preserved so
  the current Java code can start without an immediate mapping change.
- `user_id`, `group_admin`, `member_name`, and `messages.user_name` contain the
  textual username used by the frontend.
- Only the `worldmaster` seed account can be recovered from the surviving files.
  The missing dump's application records cannot be reconstructed from the UML.

## Recommended follow-up

After the application is running again, change the two post entity mappings from
`@JoinColumn(name = "post_id")` to a clearly named numeric column such as
`user_pk`, or normalize all username references to a numeric `user_id`. That
should be handled as a coordinated Java-and-database migration rather than as
part of the initial recovery.
