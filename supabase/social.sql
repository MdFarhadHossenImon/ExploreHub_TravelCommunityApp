-- ExploreHub social features: travel buddies, stories, reactions, messaging,
-- groups and trip plans. Run AFTER schema.sql in the Supabase SQL editor.
-- Every table has row level security; users can only change their own rows.

-- ============ PROFILE EXTRAS ============
alter table public.profiles add column if not exists bio text;
alter table public.profiles add column if not exists home text;
alter table public.profiles add column if not exists cover_url text;
alter table public.profiles add column if not exists countries text[] not null default '{}';
alter table public.profiles add column if not exists verified boolean not null default false;
alter table public.profiles add column if not exists next_place_id text references public.places(id) on delete set null;

-- ============ TRAVEL BUDDIES (friend requests) ============
create table if not exists public.buddy_requests (
  from_id uuid not null references public.profiles(id) on delete cascade,
  to_id   uuid not null references public.profiles(id) on delete cascade,
  status  text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  primary key (from_id, to_id),
  check (from_id <> to_id)
);
create index if not exists buddy_requests_to_idx on public.buddy_requests(to_id, status);

-- Accepted buddies in both directions, handy for queries.
create or replace view public.buddies with (security_invoker = true) as
  select from_id as user_id, to_id as buddy_id from public.buddy_requests where status = 'accepted'
  union all
  select to_id, from_id from public.buddy_requests where status = 'accepted';

-- ============ STORIES (expire after 24 h) ============
create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  media_url text not null,
  caption text,
  place_id text references public.places(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours'
);
create table if not exists public.story_views (
  story_id uuid not null references public.stories(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key (story_id, user_id)
);

-- ============ REACTIONS (extends likes) ============
alter table public.likes add column if not exists emoji text not null default '❤️';

-- ============ MESSAGING ============
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  title text,
  is_group boolean not null default false,
  trip_id uuid,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);
create table if not exists public.messages (
  id bigint generated always as identity primary key,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  media_url text,
  created_at timestamptz not null default now()
);
create index if not exists messages_conv_idx on public.messages(conversation_id, created_at);

create or replace function public.is_member(conv uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.conversation_members m where m.conversation_id = conv and m.user_id = auth.uid());
$$;

-- ============ GROUPS ============
create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  about text,
  category text not null default 'Community',
  cover_url text,
  private boolean not null default false,
  rules text[] not null default '{}',
  owner_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('member', 'admin')),
  status text not null default 'active' check (status in ('active', 'pending')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
alter table public.posts add column if not exists group_id uuid references public.groups(id) on delete cascade;

create or replace function public.is_group_member(g uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.group_members m where m.group_id = g and m.user_id = auth.uid() and m.status = 'active');
$$;

-- ============ TRIP PLANNER ============
create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  place_id text references public.places(id) on delete set null,
  start_date date not null,
  days int not null default 1 check (days between 1 and 90),
  budget numeric(10,2) not null default 0,
  public boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.trip_members (
  trip_id uuid not null references public.trips(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  primary key (trip_id, user_id)
);
create table if not exists public.trip_stops (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  day int not null check (day >= 0),
  at_time text,
  title text not null,
  note text,
  kind text not null default 'sight',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create or replace function public.can_edit_trip(t uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.trips x where x.id = t and x.owner_id = auth.uid())
      or exists (select 1 from public.trip_members m where m.trip_id = t and m.user_id = auth.uid());
$$;

-- ============ ROW LEVEL SECURITY ============
alter table public.buddy_requests       enable row level security;
alter table public.stories              enable row level security;
alter table public.story_views          enable row level security;
alter table public.conversations        enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages             enable row level security;
alter table public.groups               enable row level security;
alter table public.group_members        enable row level security;
alter table public.trips                enable row level security;
alter table public.trip_members         enable row level security;
alter table public.trip_stops           enable row level security;

create policy "buddy read own" on public.buddy_requests for select to authenticated using (auth.uid() in (from_id, to_id));
create policy "buddy send" on public.buddy_requests for insert to authenticated with check (from_id = auth.uid() and status = 'pending');
create policy "buddy accept" on public.buddy_requests for update to authenticated using (to_id = auth.uid()) with check (to_id = auth.uid());
create policy "buddy remove" on public.buddy_requests for delete to authenticated using (auth.uid() in (from_id, to_id));

create policy "stories readable" on public.stories for select to authenticated using (expires_at > now());
create policy "stories insert own" on public.stories for insert to authenticated with check (user_id = auth.uid());
create policy "stories delete own" on public.stories for delete to authenticated using (user_id = auth.uid());
create policy "story views own" on public.story_views for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "conv read member" on public.conversations for select to authenticated using (public.is_member(id));
create policy "conv create" on public.conversations for insert to authenticated with check (created_by = auth.uid());
create policy "conv members read" on public.conversation_members for select to authenticated using (public.is_member(conversation_id));
create policy "conv members add" on public.conversation_members for insert to authenticated
  with check (user_id = auth.uid() or public.is_member(conversation_id));
create policy "conv members update own" on public.conversation_members for update to authenticated using (user_id = auth.uid());
create policy "conv leave" on public.conversation_members for delete to authenticated using (user_id = auth.uid());
create policy "messages read member" on public.messages for select to authenticated using (public.is_member(conversation_id));
create policy "messages send member" on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and public.is_member(conversation_id));

create policy "groups readable" on public.groups for select to authenticated using (true);
create policy "groups create" on public.groups for insert to authenticated with check (owner_id = auth.uid());
create policy "groups update owner" on public.groups for update to authenticated using (owner_id = auth.uid());
create policy "group members read" on public.group_members for select to authenticated using (true);
create policy "group join" on public.group_members for insert to authenticated with check (
  user_id = auth.uid() and (
    status = 'pending'
    or not (select g.private from public.groups g where g.id = group_id)
  )
);
create or replace function public.is_group_admin(g uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.group_members m where m.group_id = g and m.user_id = auth.uid() and m.role = 'admin');
$$;
create policy "group admin approve" on public.group_members for update to authenticated using (public.is_group_admin(group_id));
create policy "group leave" on public.group_members for delete to authenticated using (user_id = auth.uid());

-- Private-group posts are only visible to members (replaces the open posts policy).
drop policy if exists "posts readable" on public.posts;
create policy "posts readable" on public.posts for select to authenticated using (
  group_id is null
  or not (select g.private from public.groups g where g.id = group_id)
  or public.is_group_member(group_id)
);

create policy "trips read" on public.trips for select to authenticated using (
  owner_id = auth.uid() or public.can_edit_trip(id)
  or (public and exists (select 1 from public.buddies b where b.user_id = auth.uid() and b.buddy_id = owner_id))
);
create policy "trips insert own" on public.trips for insert to authenticated with check (owner_id = auth.uid());
create policy "trips update own" on public.trips for update to authenticated using (owner_id = auth.uid());
create policy "trips delete own" on public.trips for delete to authenticated using (owner_id = auth.uid());
create policy "trip members read" on public.trip_members for select to authenticated using (public.can_edit_trip(trip_id));
create policy "trip members invite" on public.trip_members for insert to authenticated
  with check (exists (select 1 from public.trips t where t.id = trip_id and t.owner_id = auth.uid()));
create policy "trip members leave" on public.trip_members for delete to authenticated using (
  user_id = auth.uid() or exists (select 1 from public.trips t where t.id = trip_id and t.owner_id = auth.uid())
);
create policy "trip stops read" on public.trip_stops for select to authenticated using (public.can_edit_trip(trip_id));
create policy "trip stops write" on public.trip_stops for insert to authenticated with check (public.can_edit_trip(trip_id));
create policy "trip stops delete" on public.trip_stops for delete to authenticated using (public.can_edit_trip(trip_id));

-- ============ REALTIME ============
-- New chat messages and buddy requests are pushed to open apps.
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.buddy_requests;

-- ============ NOTIFICATIONS ============
create or replace function public.notify_buddy_request()
returns trigger language plpgsql security definer set search_path = '' as $$
declare who text;
begin
  select name into who from public.profiles where id = new.from_id;
  if tg_op = 'INSERT' then
    insert into public.notifications (user_id, kind, title, body)
    values (new.to_id, 'buddy', coalesce(who, 'A traveler') || ' wants to be your travel buddy', 'Open Travel buddies to confirm.');
  elsif tg_op = 'UPDATE' and new.status = 'accepted' and old.status <> 'accepted' then
    select name into who from public.profiles where id = new.to_id;
    insert into public.notifications (user_id, kind, title, body)
    values (new.from_id, 'buddy', coalesce(who, 'A traveler') || ' accepted your buddy request', 'You can now plan trips together.');
  end if;
  return new;
end $$;
drop trigger if exists on_buddy_request on public.buddy_requests;
create trigger on_buddy_request after insert or update on public.buddy_requests
  for each row execute function public.notify_buddy_request();

-- ============ FEED VIEW (adds group posts + author avatar) ============
create or replace view public.posts_feed with (security_invoker = true) as
select
  p.id, p.user_id, p.place_id, p.group_id, p.caption, p.media_url, p.is_video, p.created_at,
  pr.name as author_name,
  pr.avatar_url as author_avatar,
  (select count(*) from public.likes l where l.post_id = p.id) as like_count,
  (select count(*) from public.comments c where c.post_id = p.id) as comment_count
from public.posts p
join public.profiles pr on pr.id = p.user_id
where not exists (
  select 1 from public.blocks b where b.blocker_id = auth.uid() and b.blocked_id = p.user_id
);

-- ============ REAL PHOTOS FOR PLACES ============
alter table public.places add column if not exists image_url text;
alter table public.places add column if not exists wiki_title text;

-- ============ STARTER GROUPS (real communities, no fake members) ============
alter table public.groups add column if not exists slug text unique;
insert into public.groups (slug, name, about, category, private, rules) values
 ('travelers-of-bangladesh', 'Travelers of Bangladesh', 'Routes, prices and safety updates from every corner of Bangladesh: hill tracts, haor, beaches and the Sundarbans.', 'Country', false, array['Share real prices and dates','No hotel advertising','Be kind to locals and to each other']),
 ('solo-female-travelers', 'Solo Female Travelers', 'A safe space for women who travel alone. Ask anything, share stays and meet travel buddies.', 'Community', true, array['Women only','No sharing screenshots outside the group']),
 ('backpackers-on-a-budget', 'Backpackers on a Budget', 'Hostels, night buses, free walking tours and cheap eats. Always include prices.', 'Budget', false, array['Include prices','No referral links']),
 ('scuba-and-snorkel', 'Scuba & Snorkel Spots', 'Dive sites, conditions, liveaboards and a buddy finder for divers and snorkelers.', 'Activity', false, array['Respect marine life','Tag the dive site']),
 ('himalaya-trekkers', 'Himalaya Trekkers', 'Permits, porters, teahouses and altitude advice for treks in Nepal, India and Bhutan.', 'Activity', false, array['No unlicensed guide ads','Share altitude safety info']),
 ('street-food-explorers', 'Street Food Explorers', 'Where locals actually eat: maps, prices and hygiene tips.', 'Food', false, array['Name the stall and area'])
on conflict (slug) do nothing;

-- Group creator becomes its first admin.
create or replace function public.add_group_owner()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.owner_id is not null then
    insert into public.group_members (group_id, user_id, role, status) values (new.id, new.owner_id, 'admin', 'active')
    on conflict do nothing;
  end if;
  return new;
end $$;
drop trigger if exists on_group_created on public.groups;
create trigger on_group_created after insert on public.groups for each row execute function public.add_group_owner();

-- Member counts for group cards.
create or replace view public.groups_view with (security_invoker = true) as
select g.*, (select count(*) from public.group_members m where m.group_id = g.id and m.status = 'active') as member_count
from public.groups g;

-- Start (or reuse) a one-to-one chat with another traveler. Returns the conversation id.
create or replace function public.dm_with(other uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare cid uuid;
begin
  select c.id into cid from public.conversations c
  where not c.is_group
    and exists (select 1 from public.conversation_members m where m.conversation_id = c.id and m.user_id = auth.uid())
    and exists (select 1 from public.conversation_members m where m.conversation_id = c.id and m.user_id = other)
  limit 1;
  if cid is null then
    insert into public.conversations (is_group, created_by) values (false, auth.uid()) returning id into cid;
    insert into public.conversation_members (conversation_id, user_id) values (cid, auth.uid()), (cid, other);
  end if;
  return cid;
end $$;
revoke all on function public.dm_with(uuid) from public, anon;
grant execute on function public.dm_with(uuid) to authenticated;

-- Trip owner is always a member (simplifies reads).
create or replace function public.add_trip_owner()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.trip_members (trip_id, user_id) values (new.id, new.owner_id) on conflict do nothing;
  return new;
end $$;
drop trigger if exists on_trip_created on public.trips;
create trigger on_trip_created after insert on public.trips for each row execute function public.add_trip_owner();

-- Group posts only by group members.
drop policy if exists "posts insert own" on public.posts;
create policy "posts insert own" on public.posts for insert to authenticated
  with check (user_id = auth.uid() and (group_id is null or public.is_group_member(group_id)));

-- Changing a reaction updates the existing like row.
drop policy if exists "likes update own" on public.likes;
create policy "likes update own" on public.likes for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Profiles with public counts for profile pages.
create or replace view public.profiles_view with (security_invoker = true) as
select p.*,
  (select count(*) from public.follows f where f.following_id = p.id) as followers,
  (select count(*) from public.follows f where f.follower_id = p.id) as following,
  (select count(*) from public.trip_members t where t.user_id = p.id) as trips
from public.profiles p;
