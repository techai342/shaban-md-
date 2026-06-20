-- Run this once in the Supabase SQL Editor for https://fdsczrswgilxqrrwvkhz.supabase.co
-- It creates the shared channel/admin tables, public REST policies, and view tracking RPC used by index.html.

create table if not exists public.channels (
  channel_id bigint primary key,
  channel_name text not null,
  channel_slug text not null unique,
  channel_description text default 'Live Channel',
  logo text default '',
  category text default 'Entertainment',
  port text default '8087',
  stream_url text not null default '',
  sort_order integer default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.channel_views (
  channel_slug text primary key,
  channel_name text not null default '',
  channel_category text not null default '',
  total_views bigint not null default 0,
  today_views bigint not null default 0,
  view_date date not null default current_date,
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_channels_updated_at on public.channels;
create trigger set_channels_updated_at
before update on public.channels
for each row execute function public.set_updated_at();

create or replace function public.track_channel_view(
  p_channel_slug text,
  p_channel_name text default '',
  p_channel_category text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.channel_views (channel_slug, channel_name, channel_category, total_views, today_views, view_date, updated_at)
  values (p_channel_slug, p_channel_name, p_channel_category, 1, 1, current_date, now())
  on conflict (channel_slug) do update set
    channel_name = excluded.channel_name,
    channel_category = excluded.channel_category,
    total_views = public.channel_views.total_views + 1,
    today_views = case
      when public.channel_views.view_date = current_date then public.channel_views.today_views + 1
      else 1
    end,
    view_date = current_date,
    updated_at = now();
end;
$$;

create or replace view public.channel_view_summary as
select
  channel_slug,
  channel_name,
  channel_category,
  total_views,
  case when view_date = current_date then today_views else 0 end as today_views,
  view_date,
  updated_at
from public.channel_views;

alter table public.channels enable row level security;
alter table public.channel_views enable row level security;

drop policy if exists "Public can read channels" on public.channels;
create policy "Public can read channels" on public.channels
for select using (true);

drop policy if exists "Public admin can insert channels" on public.channels;
create policy "Public admin can insert channels" on public.channels
for insert with check (true);

drop policy if exists "Public admin can update channels" on public.channels;
create policy "Public admin can update channels" on public.channels
for update using (true) with check (true);

drop policy if exists "Public admin can delete channels" on public.channels;
create policy "Public admin can delete channels" on public.channels
for delete using (true);

drop policy if exists "Public can read channel views" on public.channel_views;
create policy "Public can read channel views" on public.channel_views
for select using (true);

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.channels to anon, authenticated;
grant select on public.channel_views to anon, authenticated;
grant select on public.channel_view_summary to anon, authenticated;
grant execute on function public.track_channel_view(text, text, text) to anon, authenticated;
