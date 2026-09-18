-- Shared Desk collaboration feed and many-to-many visibility helpers.
-- Keeps the feed scoped to current members and exposes only profile display data
-- that members already see in the Shared Desk member directory.

create or replace function public.get_shared_desk_activity(
  p_desk_id uuid,
  p_limit integer default 40
)
returns table (
  kind text,
  entity_id uuid,
  title text,
  detail text,
  actor_id uuid,
  actor_name text,
  actor_avatar_url text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with activity as (
    select
      'document'::text as kind,
      d.id as entity_id,
      d.title,
      concat('Shared a ', coalesce(nullif(d.category, ''), 'document'))::text as detail,
      d.owner_id as actor_id,
      d.created_at
    from public.documents d
    where d.desk_id = p_desk_id
      and d.visibility = 'desk'

    union all

    select
      'task'::text,
      t.id,
      t.title,
      concat('Created a ', coalesce(nullif(t.priority, ''), 'medium'), '-priority task')::text,
      t.creator_id,
      t.created_at
    from public.tasks t
    where t.desk_id = p_desk_id

    union all

    select
      'bill'::text,
      b.id,
      b.title,
      concat('Added bill · Rs. ', trim(to_char(b.amount, 'FM9999999990.00')))::text,
      b.owner_id,
      b.created_at
    from public.bills b
    where b.desk_id = p_desk_id
  )
  select
    a.kind,
    a.entity_id,
    a.title,
    a.detail,
    a.actor_id,
    coalesce(nullif(p.full_name, ''), 'Member') as actor_name,
    p.avatar_url as actor_avatar_url,
    a.created_at
  from activity a
  left join public.profiles p on p.id = a.actor_id
  where public.is_desk_member(p_desk_id)
  order by a.created_at desc
  limit greatest(1, least(coalesce(p_limit, 40), 100));
$$;

grant execute on function public.get_shared_desk_activity(uuid, integer) to authenticated;
