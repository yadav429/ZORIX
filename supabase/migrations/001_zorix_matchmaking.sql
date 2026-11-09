-- ZORIX free-tier matchmaking schema for Supabase.
-- Run this file in Supabase SQL Editor. Clients must use Supabase Anonymous Auth.
create extension if not exists pgcrypto;

create table if not exists public.zorix_queue (
  user_id uuid primary key references auth.users(id) on delete cascade,
  mode text not null check (mode in ('Solo','Duo','Squad')),
  queued_at timestamptz not null default now(),
  match_id uuid
);

create table if not exists public.zorix_matches (
  id uuid primary key default gen_random_uuid(),
  mode text not null check (mode in ('Solo','Duo','Squad')),
  status text not null default 'waiting' check (status in ('waiting','ready','cancelled')),
  created_at timestamptz not null default now(),
  player_count integer not null default 0
);

create table if not exists public.zorix_match_players (
  match_id uuid not null references public.zorix_matches(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  team_number integer not null,
  joined_at timestamptz not null default now(),
  primary key (match_id, user_id)
);

alter table public.zorix_queue enable row level security;
alter table public.zorix_matches enable row level security;
alter table public.zorix_match_players enable row level security;

-- No direct table access from clients. All queue operations go through RPC.
revoke all on public.zorix_queue, public.zorix_matches, public.zorix_match_players from anon, authenticated;
create or replace function public.zorix_join_queue(p_mode text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_count integer;
  v_match uuid;
  v_team_size integer;
  v_position integer;
begin
  if v_uid is null then raise exception 'Sign in anonymously before matchmaking'; end if;
  if p_mode not in ('Solo','Duo','Squad') then raise exception 'Invalid mode'; end if;

  -- Serialize queue formation for this mode to prevent duplicate matches.
  perform pg_advisory_xact_lock(hashtext('zorix-' || p_mode));
  delete from public.zorix_queue where queued_at < now() - interval '10 minutes' and match_id is null;

  if exists (select 1 from public.zorix_queue where user_id = v_uid and match_id is not null) then
    return public.zorix_queue_status();
  end if;

  insert into public.zorix_queue(user_id, mode, queued_at, match_id)
  values (v_uid, p_mode, now(), null)
  on conflict (user_id) do update set mode = excluded.mode, queued_at = now(), match_id = null;

  select count(*) into v_count from public.zorix_queue
    where mode = p_mode and match_id is null and queued_at >= now() - interval '10 minutes';

  if v_count >= 50 then
    v_match := gen_random_uuid();
    v_team_size := case p_mode when 'Solo' then 1 when 'Duo' then 2 else 4 end;
    insert into public.zorix_matches(id, mode, status, player_count)
      values (v_match, p_mode, 'ready', 50);

    with chosen as (
      select user_id, row_number() over (order by queued_at, user_id) as rn
      from public.zorix_queue
      where mode = p_mode and match_id is null and queued_at >= now() - interval '10 minutes'
      order by queued_at, user_id
      limit 50
    ), assigned as (
      insert into public.zorix_match_players(match_id, user_id, team_number)
      select v_match, user_id, ceil(rn::numeric / v_team_size)::integer from chosen
      returning user_id
    )
    update public.zorix_queue q set match_id = v_match
      where q.user_id in (select user_id from assigned);
  end if;

  return public.zorix_queue_status();
end;
$$;

create or replace function public.zorix_leave_queue()
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  delete from public.zorix_queue where user_id = v_uid and match_id is null;
  return jsonb_build_object('left_queue', true);
end;
$$;

create or replace function public.zorix_queue_status()
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.zorix_queue%rowtype;
  v_count integer;
  v_position integer;
  v_team integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select * into v_row from public.zorix_queue where user_id = v_uid;
  if not found then return jsonb_build_object('state','not_queued'); end if;
  if v_row.match_id is not null then
    select team_number into v_team from public.zorix_match_players
      where match_id = v_row.match_id and user_id = v_uid;
    return jsonb_build_object('state','matched','match_id',v_row.match_id,'mode',v_row.mode,'team_number',v_team);
  end if;
  select count(*) into v_count from public.zorix_queue
    where mode = v_row.mode and match_id is null and queued_at >= now() - interval '10 minutes';
  select count(*) + 1 into v_position from public.zorix_queue
    where mode = v_row.mode and match_id is null and queued_at < v_row.queued_at;
  return jsonb_build_object('state','searching','mode',v_row.mode,'players_waiting',v_count,'players_needed',greatest(0,50-v_count),'queue_position',v_position);
end;
$$;

revoke all on function public.zorix_join_queue(text), public.zorix_leave_queue(), public.zorix_queue_status() from public;
grant execute on function public.zorix_join_queue(text), public.zorix_leave_queue(), public.zorix_queue_status() to authenticated;
