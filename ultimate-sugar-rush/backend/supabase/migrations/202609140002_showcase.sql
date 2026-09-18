-- Extend the existing allowlist while preserving the deployed function's access rules.
do $migration$
declare
  original text := pg_get_functiondef('public.cafe_social(text,jsonb)'::regprocedure);
  revised text;
begin
  if position('''display'',coalesce(snapshot_input' in original)>0 then return; end if;
  revised := replace(original,'''seating'',coalesce(',
    '''display'',coalesce(snapshot_input->''upgrades''->''display'' = ''true''::jsonb,false),''seating'',coalesce(');
  if revised=original then raise exception 'Expected showcase insertion point not found'; end if;
  execute revised;
end;
$migration$;
