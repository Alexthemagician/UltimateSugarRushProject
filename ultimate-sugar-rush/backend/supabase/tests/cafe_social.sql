-- Run against a disposable Supabase database after applying migrations.
-- Everything is rolled back, including temporary Auth users.
begin;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select public.cafe_social('register','{"display_name":"Mint test"}');
select public.cafe_social('publish','{"layout":{"version":1,"theme":"mint","table_position":[4.5,0],"wallet":999999,"upgrades":{"garden":true}}}');
select set_config('test.owner_code',public.cafe_social('profile')->>'code',true);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select public.cafe_social('register','{"display_name":"Berry test"}');
select set_config('test.visitor_code',public.cafe_social('profile')->>'code',true);
do $$
declare snapshot jsonb;
begin
  snapshot := public.cafe_social('visit',jsonb_build_object('code',current_setting('test.owner_code')));
  assert snapshot->'layout'->>'theme'='mint', 'Offline snapshot is readable';
  assert not (snapshot->'layout' ? 'wallet'), 'Private save data must be discarded';
  assert not (snapshot ? 'owner'), 'Private UUID must not be exposed';
  perform public.cafe_social('publish',jsonb_build_object(
    'owner','00000000-0000-0000-0000-000000000001',
    'layout',jsonb_build_object('version',1,'theme','cocoa','table_position',jsonb_build_array(4,0))));
  snapshot := public.cafe_social('visit',jsonb_build_object('code',current_setting('test.owner_code')));
  assert snapshot->'layout'->>'theme'='mint', 'Forged owner field cannot overwrite another cafe';
  begin
    perform public.cafe_social('publish','{"layout":{"version":1,"theme":"mint","table_position":[999,0]}}');
    raise exception 'Out-of-bounds layout was accepted';
  exception when raise_exception then
    if sqlerrm <> 'Invalid furniture' then raise; end if;
  end;
  begin
    perform public.cafe_social('publish','{"layout":{"version":1,"theme":"mint","table_position":[4,0],"display_style":"unknown"}}');
    raise exception 'Unknown finish was accepted';
  exception when raise_exception then
    if sqlerrm <> 'Invalid display finish' then raise; end if;
  end;
  begin
    perform 1 from cafe_private.profiles;
    raise exception 'Direct private-table access was allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.cafe_social('accept',jsonb_build_object('code',current_setting('test.owner_code')));
    raise exception 'Requestless acceptance was allowed';
  exception when raise_exception then
    if sqlerrm <> 'No incoming request' then raise; end if;
  end;
end $$;
select public.cafe_social('request',jsonb_build_object('code',current_setting('test.owner_code')));
select public.cafe_social('request',jsonb_build_object('code',current_setting('test.owner_code')));
do $$ begin
  assert jsonb_array_length(public.cafe_social('friends')->'friends')=1, 'Duplicate requests are idempotent';
  assert public.cafe_social('friends')->'friends'->0->>'status'='outgoing';
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
do $$ begin
  assert public.cafe_social('friends')->'friends'->0->>'status'='incoming';
end $$;
select public.cafe_social('accept',jsonb_build_object('code',current_setting('test.visitor_code')));
do $$ begin
  assert public.cafe_social('friends')->'friends'->0->>'status'='friend';
end $$;
select public.cafe_social('hide');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
do $$ begin
  begin
    perform public.cafe_social('visit',jsonb_build_object('code',current_setting('test.owner_code')));
    raise exception 'Hidden cafe remained visible';
  exception when raise_exception then
    if sqlerrm <> 'This cafe is not open for visits' then raise; end if;
  end;
end $$;
select public.cafe_social('remove',jsonb_build_object('code',current_setting('test.owner_code')));
do $$ begin
  assert jsonb_array_length(public.cafe_social('friends')->'friends')=0;
end $$;
reset role;
set local role anon;
do $$ begin
  begin
    perform public.cafe_social('profile');
    raise exception 'Unauthenticated RPC was allowed';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;
