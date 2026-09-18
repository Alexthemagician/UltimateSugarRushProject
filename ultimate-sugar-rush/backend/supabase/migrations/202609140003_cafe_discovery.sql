-- Public café discovery. Internal café codes remain opaque client identifiers and are never displayed.
create or replace function public.cafe_discover()
returns jsonb language sql security definer set search_path = '' stable as $$
  select jsonb_build_object(
    'cafes',
    coalesce(jsonb_agg(jsonb_build_object(
      'code', p.code,
      'display_name', p.display_name,
      'visits_enabled', true,
      'status', coalesce((
        select case
          when f.accepted then 'friend'
          when f.recipient = auth.uid() then 'incoming'
          else 'outgoing'
        end
        from cafe_private.friendships f
        where (f.sender = auth.uid() and f.recipient = p.owner)
           or (f.sender = p.owner and f.recipient = auth.uid())
        limit 1
      ), 'none')
    ) order by s.updated_at desc), '[]'::jsonb)
  )
  from cafe_private.profiles p
  join cafe_private.snapshots s on s.owner = p.owner
  where auth.uid() is not null
    and p.owner <> auth.uid()
    and p.visits_enabled
  limit 50;
$$;

revoke all on function public.cafe_discover() from public, anon;
grant execute on function public.cafe_discover() to authenticated;
