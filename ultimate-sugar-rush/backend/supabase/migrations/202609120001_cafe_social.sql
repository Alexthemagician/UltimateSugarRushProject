-- Clients access only cafe_social; account UUIDs and private rows are never exposed.
create schema if not exists cafe_private;
revoke all on schema cafe_private from public, anon, authenticated;

create table cafe_private.profiles (
  owner uuid primary key references auth.users(id) on delete cascade,
  code text unique not null default upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)),
  display_name text not null check (length(display_name) between 1 and 32),
  visits_enabled boolean not null default false
);
create table cafe_private.snapshots (
  owner uuid primary key references cafe_private.profiles(owner) on delete cascade,
  layout jsonb not null,
  revision bigint not null default 1,
  updated_at timestamptz not null default now(),
  check (octet_length(layout::text) <= 16384)
);
create table cafe_private.friendships (
  sender uuid not null references cafe_private.profiles(owner) on delete cascade,
  recipient uuid not null references cafe_private.profiles(owner) on delete cascade,
  accepted boolean not null default false,
  created_at timestamptz not null default now(),
  primary key(sender,recipient),
  check(sender <> recipient)
);
create unique index friendship_pair on cafe_private.friendships
  (least(sender,recipient),greatest(sender,recipient));
alter table cafe_private.profiles enable row level security;
alter table cafe_private.snapshots enable row level security;
alter table cafe_private.friendships enable row level security;
revoke all on all tables in schema cafe_private from public, anon, authenticated;

create function public.cafe_social(action text, payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  other uuid;
  profile cafe_private.profiles;
  name_input text;
  snapshot_input jsonb;
  result jsonb;
begin
  if me is null then raise exception 'Sign in to use cafe visits'; end if;
  if payload is null or jsonb_typeof(payload) <> 'object' then raise exception 'Invalid request'; end if;
  if action = 'register' then
    name_input := trim(payload->>'display_name');
    if name_input is null or length(name_input) not between 1 and 32 then
      raise exception 'Choose a name of 1 to 32 characters';
    end if;
    insert into cafe_private.profiles(owner,display_name) values(me,name_input)
      on conflict(owner) do update set display_name=excluded.display_name;
  end if;
  select * into profile from cafe_private.profiles where owner=me;
  if not found then raise exception 'Create your cafe profile first'; end if;
  if action in ('register','profile') then
    return jsonb_build_object('code',profile.code,'display_name',profile.display_name,'visits_enabled',profile.visits_enabled);
  elsif action = 'publish' then
    snapshot_input := payload->'layout';
    if snapshot_input is null or jsonb_typeof(snapshot_input) <> 'object'
       or snapshot_input->>'version' is distinct from '1'
       or octet_length(snapshot_input::text)>16384 then raise exception 'Invalid cafe layout'; end if;
    -- Construct the public payload explicitly. Never persist a caller's full save file.
    if snapshot_input->>'theme' not in ('strawberry','mint','cocoa')
       or snapshot_input->>'theme' is null then raise exception 'Invalid theme'; end if;
    if jsonb_typeof(snapshot_input->'table_position') is distinct from 'array'
       or jsonb_array_length(snapshot_input->'table_position') <> 2 then raise exception 'Invalid furniture'; end if;
    if jsonb_typeof(snapshot_input->'table_position'->0) <> 'number'
       or jsonb_typeof(snapshot_input->'table_position'->1) <> 'number'
       or (snapshot_input->'table_position'->>0)::numeric not between 3.5 and 5.5
       or (snapshot_input->'table_position'->>1)::numeric not between -1.5 and 1.5 then raise exception 'Invalid furniture'; end if;
    if coalesce(snapshot_input->>'display_style','rose') not in ('rose','sage','walnut') then raise exception 'Invalid display finish'; end if;
    snapshot_input := jsonb_build_object('version',1,'theme',snapshot_input->>'theme',
      'display_style',coalesce(snapshot_input->>'display_style','rose'),
      'table_position',snapshot_input->'table_position',
      'upgrades',jsonb_build_object(
        'oven',coalesce(snapshot_input->'upgrades'->'oven' = 'true'::jsonb,false),
        'garden',coalesce(snapshot_input->'upgrades'->'garden' = 'true'::jsonb,false),
        'seating',coalesce(snapshot_input->'upgrades'->'seating' = 'true'::jsonb,false)));
    insert into cafe_private.snapshots(owner,layout) values(me,snapshot_input)
      on conflict(owner) do update set layout=excluded.layout,
        revision=cafe_private.snapshots.revision+1,updated_at=now();
    update cafe_private.profiles set visits_enabled=true where owner=me;
    return jsonb_build_object('published',true);
  elsif action = 'hide' then
    update cafe_private.profiles set visits_enabled=false where owner=me;
    return jsonb_build_object('hidden',true);
  elsif action = 'friends' then
    select coalesce(jsonb_agg(jsonb_build_object('code',p.code,'display_name',p.display_name,
      'status',case when f.accepted then 'friend' when f.recipient=me then 'incoming' else 'outgoing' end,
      'visits_enabled',p.visits_enabled) order by p.display_name),'[]'::jsonb) into result
    from cafe_private.friendships f join cafe_private.profiles p
      on p.owner=case when f.sender=me then f.recipient else f.sender end
    where me in (f.sender,f.recipient);
    return jsonb_build_object('friends',result);
  end if;

  select owner into other from cafe_private.profiles where code=upper(trim(payload->>'code'));
  if other is null then raise exception 'Cafe code not found'; end if;
  if action = 'visit' then
    select jsonb_build_object('code',p.code,'display_name',p.display_name,'layout',s.layout,
      'revision',s.revision,'updated_at',s.updated_at) into result
    from cafe_private.profiles p join cafe_private.snapshots s on s.owner=p.owner
    where p.owner=other and (p.visits_enabled or p.owner=me);
    if result is null then raise exception 'This cafe is not open for visits'; end if;
    return result;
  elsif action = 'request' then
    if other=me then raise exception 'This is your own code'; end if;
    -- Lock both profiles in a stable order so concurrent requests respect both limits.
    perform 1 from cafe_private.profiles where owner in (me,other) order by owner for update;
    if exists(select 1 from cafe_private.friendships
      where (sender=me and recipient=other) or (sender=other and recipient=me)) then
      return jsonb_build_object('requested',true);
    end if;
    if (select count(*) from cafe_private.friendships where sender=me or recipient=me)>=100 then
      raise exception 'Your friends list is full'; end if;
    if (select count(*) from cafe_private.friendships where sender=other or recipient=other)>=100 then
      raise exception 'This cafe cannot receive more friend requests'; end if;
    insert into cafe_private.friendships(sender,recipient) values(me,other) on conflict do nothing;
    return jsonb_build_object('requested',true);
  elsif action = 'accept' then
    update cafe_private.friendships set accepted=true where sender=other and recipient=me;
    if not found then raise exception 'No incoming request'; end if;
    return jsonb_build_object('accepted',true);
  elsif action = 'remove' then
    delete from cafe_private.friendships where (sender=me and recipient=other) or (sender=other and recipient=me);
    return jsonb_build_object('removed',true);
  end if;
  raise exception 'Unknown cafe action';
end;
$$;
revoke all on function public.cafe_social(text,jsonb) from public, anon;
grant execute on function public.cafe_social(text,jsonb) to authenticated;
