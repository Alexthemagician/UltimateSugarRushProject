-- Friend requests accept immediately. The pair remains removable by either player.
create or replace function public.cafe_friend_action(action text, payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  other uuid;
begin
  if me is null then raise exception 'Sign in to use cafe visits'; end if;
  select owner into other from cafe_private.profiles where code=upper(trim(payload->>'code'));
  if other is null then raise exception 'Cafe code not found'; end if;
  if other=me then raise exception 'This is your own code'; end if;
  if action='request' then
    perform 1 from cafe_private.profiles where owner in (me,other) order by owner for update;
    if not exists(select 1 from cafe_private.friendships where (sender=me and recipient=other) or (sender=other and recipient=me)) then
      if (select count(*) from cafe_private.friendships where sender=me or recipient=me)>=100 then raise exception 'Your friends list is full'; end if;
      if (select count(*) from cafe_private.friendships where sender=other or recipient=other)>=100 then raise exception 'This cafe cannot receive more friend requests'; end if;
      insert into cafe_private.friendships(sender,recipient,accepted) values(me,other,true);
    else
      update cafe_private.friendships set accepted=true where (sender=me and recipient=other) or (sender=other and recipient=me);
    end if;
    return jsonb_build_object('accepted',true);
  elsif action='remove' then
    delete from cafe_private.friendships where (sender=me and recipient=other) or (sender=other and recipient=me);
    return jsonb_build_object('removed',true);
  end if;
  raise exception 'Unknown friend action';
end;
$$;
revoke all on function public.cafe_friend_action(text,jsonb) from public, anon;
grant execute on function public.cafe_friend_action(text,jsonb) to authenticated;
