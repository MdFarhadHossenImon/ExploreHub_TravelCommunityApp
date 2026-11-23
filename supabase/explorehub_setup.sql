-- ExploreHub: complete live database setup (schema + social features + real places + photos).
-- Paste everything into Supabase > SQL Editor > New query, then press Run.

-- ExploreHub database schema for Supabase (PostgreSQL).
-- Run this once in: Supabase Dashboard > SQL Editor > New query > paste > Run.
-- Then run seed.sql.

-- ============ PROFILES ============
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default 'Traveler',
  username text unique check (username ~ '^[A-Za-z0-9_.]{3,30}$'),
  avatar_url text,
  created_at timestamptz not null default now()
);

-- Create a profile automatically for every new auth user.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'name', ''), split_part(new.email, '@', 1), 'Traveler')
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============ CATALOG ============
create table if not exists public.places (
  id text primary key,
  name text not null,
  location text not null,
  country text not null,
  category text not null,
  hub text not null,
  rating numeric(2,1) not null default 0,
  reviews int not null default 0,
  price numeric(10,2) not null default 0,
  about text not null default '',
  season text not null default '',
  last_mode text not null default 'car',
  last_detail text not null default '',
  last_duration text not null default '',
  facilities text[] not null default '{}',
  address text,
  lat double precision,
  lng double precision,
  hours text,
  maps_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.guides (
  id text primary key,
  name text not null,
  base text not null,
  bio text not null default '',
  rating numeric(2,1) not null default 0,
  price_per_day numeric(10,2) not null default 0,
  years int not null default 0,
  languages text[] not null default '{}'
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  place_id text not null references public.places(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  rating numeric(2,1) not null check (rating between 1 and 5),
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

-- ============ COMMUNITY ============
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  place_id text references public.places(id) on delete set null,
  caption text not null check (char_length(caption) between 1 and 2000),
  media_url text not null,
  is_video boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

create table if not exists public.follows (
  follower_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table if not exists public.saved_places (
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  place_id text not null references public.places(id) on delete cascade,
  primary key (user_id, place_id)
);

create table if not exists public.saved_posts (
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  primary key (user_id, post_id)
);

-- Safety features required by the App Store and Google Play for user-generated content.
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  reported_user_id uuid references public.profiles(id) on delete cascade,
  reason text not null check (char_length(reason) between 1 and 500),
  created_at timestamptz not null default now()
);

create table if not exists public.blocks (
  blocker_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- ============ BOOKINGS & NOTIFICATIONS ============
create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  title text not null,
  location text not null default '',
  type text not null check (type in ('tour','hotel','flight','train','bus','guide')),
  seed text not null default '',
  ref text not null unique,
  amount numeric(10,2) not null check (amount >= 0),
  start_date date not null,
  end_date date not null,
  status text not null default 'Upcoming' check (status in ('Upcoming','Completed','Cancelled')),
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null default 'app',
  title text not null,
  body text not null default '',
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists posts_created_idx on public.posts (created_at desc);
create index if not exists comments_post_idx on public.comments (post_id, created_at);
create index if not exists bookings_user_idx on public.bookings (user_id, created_at desc);
create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);
create index if not exists reviews_place_idx on public.reviews (place_id, created_at desc);

-- ============ TRIGGERS ============
create or replace function public.notify_booking()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notifications (user_id, kind, title, body)
  values (
    new.user_id,
    case when new.type = 'flight' then 'flight' else 'hotel' end,
    'Booking confirmed',
    new.title || ' is booked. Reference ' || new.ref || '.'
  );
  return new;
end $$;

drop trigger if exists on_booking_created on public.bookings;
create trigger on_booking_created after insert on public.bookings
  for each row execute function public.notify_booking();

create or replace function public.notify_like()
returns trigger language plpgsql security definer set search_path = '' as $$
declare owner uuid; who text;
begin
  select user_id into owner from public.posts where id = new.post_id;
  if owner is not null and owner <> new.user_id then
    select name into who from public.profiles where id = new.user_id;
    insert into public.notifications (user_id, kind, title, body)
    values (owner, 'community', coalesce(who, 'Someone') || ' liked your post', 'Your post is getting attention.');
  end if;
  return new;
end $$;

drop trigger if exists on_like_created on public.likes;
create trigger on_like_created after insert on public.likes
  for each row execute function public.notify_like();

-- ============ FUNCTIONS (called from the app) ============
create or replace function public.cancel_booking(b_id uuid)
returns void language sql security definer set search_path = '' as $$
  update public.bookings set status = 'Cancelled'
  where id = b_id and user_id = auth.uid() and status = 'Upcoming';
$$;

-- Account deletion is required by Apple (guideline 5.1.1(v)) for apps with account creation.
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  delete from auth.users where id = auth.uid();   -- cascades to every table above
end $$;

revoke all on function public.cancel_booking(uuid) from public, anon;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.cancel_booking(uuid) to authenticated;
grant execute on function public.delete_my_account() to authenticated;

-- ============ FEED VIEW ============
-- Counts are computed here; hides posts from users the caller has blocked.
create or replace view public.posts_feed with (security_invoker = true) as
select
  p.id, p.user_id, p.place_id, p.caption, p.media_url, p.is_video, p.created_at,
  pr.name as author_name,
  pr.avatar_url as author_avatar,
  (select count(*) from public.likes l where l.post_id = p.id) as like_count,
  (select count(*) from public.comments c where c.post_id = p.id) as comment_count
from public.posts p
join public.profiles pr on pr.id = p.user_id
where not exists (
  select 1 from public.blocks b where b.blocker_id = auth.uid() and b.blocked_id = p.user_id
);

-- ============ ROW LEVEL SECURITY ============
alter table public.profiles       enable row level security;
alter table public.places         enable row level security;
alter table public.guides         enable row level security;
alter table public.reviews        enable row level security;
alter table public.posts          enable row level security;
alter table public.likes          enable row level security;
alter table public.comments       enable row level security;
alter table public.follows        enable row level security;
alter table public.saved_places   enable row level security;
alter table public.saved_posts    enable row level security;
alter table public.reports        enable row level security;
alter table public.blocks         enable row level security;
alter table public.bookings       enable row level security;
alter table public.notifications  enable row level security;

-- Public catalog
create policy "places readable" on public.places for select using (true);
create policy "guides readable" on public.guides for select using (true);
create policy "reviews readable" on public.reviews for select using (true);
create policy "reviews insert own" on public.reviews for insert to authenticated with check (user_id = auth.uid());
create policy "reviews delete own" on public.reviews for delete to authenticated using (user_id = auth.uid());

-- Profiles
create policy "profiles readable" on public.profiles for select to authenticated using (true);
create policy "profiles update own" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Posts, likes, comments, follows
create policy "posts readable" on public.posts for select to authenticated using (true);
create policy "posts insert own" on public.posts for insert to authenticated with check (user_id = auth.uid());
create policy "posts delete own" on public.posts for delete to authenticated using (user_id = auth.uid());

create policy "likes readable" on public.likes for select to authenticated using (true);
create policy "likes insert own" on public.likes for insert to authenticated with check (user_id = auth.uid());
create policy "likes delete own" on public.likes for delete to authenticated using (user_id = auth.uid());

create policy "comments readable" on public.comments for select to authenticated using (true);
create policy "comments insert own" on public.comments for insert to authenticated with check (user_id = auth.uid());
create policy "comments delete own" on public.comments for delete to authenticated using (user_id = auth.uid());

create policy "follows readable" on public.follows for select to authenticated using (true);
create policy "follows insert own" on public.follows for insert to authenticated with check (follower_id = auth.uid());
create policy "follows delete own" on public.follows for delete to authenticated using (follower_id = auth.uid());

-- Private per-user data
create policy "saved places own" on public.saved_places for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "saved posts own" on public.saved_posts for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "blocks own" on public.blocks for all to authenticated
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
create policy "reports insert own" on public.reports for insert to authenticated with check (reporter_id = auth.uid());
-- (no select policy on reports: only you, in the dashboard, can read them)

create policy "bookings read own" on public.bookings for select to authenticated using (user_id = auth.uid());
create policy "bookings insert own" on public.bookings for insert to authenticated with check (user_id = auth.uid());
-- (no update/delete policy: cancel through the cancel_booking() function)

create policy "notifications read own" on public.notifications for select to authenticated using (user_id = auth.uid());
create policy "notifications update own" on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Column-level limits so users can only change what they should.
revoke update on public.profiles from authenticated;
grant update (name, username, avatar_url) on public.profiles to authenticated;
revoke update on public.notifications from authenticated;
grant update (read) on public.notifications to authenticated;

-- ============ STORAGE ============
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars',    'avatars',    true,  5242880,  array['image/jpeg','image/png','image/webp']),
  ('post-media', 'post-media', true,  52428800, array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Anyone can view files; users can only write inside their own folder: <user id>/<file>
create policy "media public read" on storage.objects for select
  using (bucket_id in ('avatars','post-media'));
create policy "media upload own folder" on storage.objects for insert to authenticated
  with check (bucket_id in ('avatars','post-media') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "media update own folder" on storage.objects for update to authenticated
  using (bucket_id in ('avatars','post-media') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "media delete own folder" on storage.objects for delete to authenticated
  using (bucket_id in ('avatars','post-media') and (storage.foldername(name))[1] = auth.uid()::text);

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

-- ExploreHub seed data: 15 destinations (ratings, addresses, coordinates from Google Maps).
-- Re-runnable: updates existing rows by id.
insert into public.places
 (id,name,location,country,category,hub,rating,reviews,price,about,season,last_mode,last_detail,last_duration,facilities,address,lat,lng,hours,maps_url)
values
('raja','Raja Ampat Islands','West Papua','Indonesia','Beach','Jakarta',4.6,1662,85,'A remote archipelago of 1,500+ jungle islands with the richest coral reefs on Earth. Snorkel with manta rays and sleep in stilted homestays.','Oct to Apr','boat','Fly Jakarta to Sorong, then the public ferry or speedboat to Waisai.','2 to 3 h',array['Beach access','Local guide','Meals','Transfers']::text[],'Raja Ampat Regency, Southwest Papua, Indonesia',-1.0320,130.5052,'Open access','https://maps.google.com/?cid=8669919133578354500'),
('kaptai','Kaptai Lake','Rangamati','Bangladesh','Lakes','Chattogram',4.7,2623,50,'The largest man-made lake in Bangladesh, ringed by green hills and tribal villages. Take a boat to the Hanging Bridge at sunset.','Nov to Mar','boat','Bus to Rangamati, then hire a motor boat from the main ghat.','3 h',array['Boat ride','Local guide','Lunch','Life jackets']::text[],'Kaptai Lake, Bangladesh',22.5928,92.2138,'Open access','https://maps.google.com/?cid=2442638726496692933'),
('sajek','Sajek Valley','Rangamati','Bangladesh','Mountains','Chattogram',4.6,15785,60,'The "Queen of Hills", where clouds drift below your cottage. Famous for its sea of clouds at dawn.','Jun to Oct','car','Bus to Khagrachari, then a shared jeep up the hill road. Travel in daylight.','3 to 4 h',array['Viewpoint','Local guide','Meals','Transfers']::text[],'97MV+GHF, Sajek, Bangladesh',23.3838,92.2939,'Open 24 hours','https://maps.google.com/?cid=17424561153615271756'),
('kyoto','Fushimi Inari Taisha','Kyoto','Japan','City','Osaka',4.6,92177,110,'Thousands of vermilion torii gates wind up Mount Inari on the edge of Kyoto. Entry is free and the grounds are open around the clock, so go at dawn or after dark to avoid the crowds.','Mar to Apr, Nov','train','Haruka Express from Kansai Airport straight to Kyoto Station.','75 min',array['Local guide','Breakfast','Pickup','Tickets']::text[],'68 Fukakusa Yabunouchicho, Fushimi Ward, Kyoto 612-0882, Japan',34.9677,135.7792,'Open 24 hours','https://maps.google.com/?cid=8870624639634301673'),
('machu','Machu Picchu','Cusco','Peru','Camp','Lima',4.8,85594,180,'The Inca citadel above the Urubamba valley. Hike the Inca Trail or take the train and climb at sunrise.','May to Sep','trek','Fly to Cusco, train to Aguas Calientes, then bus or climb to the gate.','6 to 8 h',array['Entry ticket','Guide','Transport','Camping gear']::text[],'Historic Sanctuary of Machu Picchu, 08680, Peru',-13.1632,-72.5453,'6:30 AM to 3:45 PM daily','https://maps.google.com/?cid=4183904589858216487'),
('cox','Cox’s Bazar Sea Beach','Cox’s Bazar','Bangladesh','Beach','Cox’s Bazar',4.6,7236,45,'The longest natural sea beach in the world, with golden sand and big sunset views over the Bay of Bengal. Drive Marine Drive to Inani Beach for quieter stretches.','Nov to Mar','car','Auto-rickshaws and jeeps run from the airport and bus terminal to Laboni Beach.','20 min',array['Beach access','Local guide','Meals','Transfers']::text[],'Cox’s Bazar Sea Beach, Cox’s Bazar, Bangladesh',21.4159,91.9810,'Open 24 hours','https://maps.google.com/?cid=18351127764277519198'),
('stm','St. Martin’s Island','Teknaf','Bangladesh','Beach','Cox’s Bazar',4.5,310,70,'The only coral island of Bangladesh, also called Narikel Jinjira (Coconut Island). Turquoise water, coconut groves and fresh seafood, with basic facilities.','Nov to Mar','boat','Take a ship from Teknaf jetty to the island. Sailings are seasonal, so confirm the schedule before you book.','2 to 3 h',array['Beach access','Local guide','Meals','Transfers']::text[],'St. Martin’s Island, Bangladesh',20.6237,92.3234,'Open access','https://maps.google.com/?cid=12778165215399126363'),
('karamjal','Karamjal (Sundarbans)','Khulna','Bangladesh','Forest','Khulna',4.3,2382,35,'A gateway to the Sundarbans mangroves, with wooden boardwalks, a crocodile and deer breeding centre, and playful monkeys. A good one-day taste of the forest.','Nov to Feb','boat','Take an engine boat from Mongla Ferry Ghat down the Pashur River to the Karamjal forest station.','2 to 3 h',array['Boat or trail','Local guide','Permits','Meals']::text[],'CHHR+9MR, Bangladesh',22.4285,89.5917,'9:00 AM to 5:00 PM','https://maps.google.com/?cid=9105068294151503598'),
('ratargul','Ratargul Swamp Forest','Sylhet','Bangladesh','Forest','Sylhet',4.5,7370,25,'The only freshwater swamp forest in Bangladesh. In the rainy season the trees stand in water and boats glide between them. Please carry your trash out.','Jun to Oct','boat','Drive from Sylhet city to Gowainghat, then hire a small wooden boat into the flooded forest.','1 to 2 h',array['Boat or trail','Local guide','Permits','Meals']::text[],'2W79+MFG, Gushainpur, Bangladesh',25.0142,91.9187,'8:00 AM to 6:00 PM','https://maps.google.com/?cid=2205115375143251257'),
('jaflong','Jaflong Zero Point','Sylhet','Bangladesh','Mountains','Sylhet',4.4,5405,30,'Green hills, clear streams and the Piyain river beside the Indian border. It gets crowded on holidays, and the monsoon is when the scenery is at its fullest.','Jun to Oct','car','Drive or take a shared car from Sylhet to Jaflong on the Dauki river near the border.','2 to 3 h',array['Viewpoint','Local guide','Meals','Transfers']::text[],'Jaflong, Bangladesh',25.1823,92.0179,'Open access','https://maps.google.com/?cid=12875285867582531005'),
('nilgiri','Nilgiri Hill Resort','Bandarban','Bangladesh','Mountains','Chattogram',4.4,6163,65,'A hilltop in Bandarban where clouds drift right through the resort. Stay overnight for sunrise and sunset above the clouds.','Jun to Oct','car','Take a bus to Bandarban town, then a jeep or Chander Gari up to the hilltop. The resort is army-run.','2 to 3 h',array['Viewpoint','Local guide','Meals','Transfers']::text[],'Bandarban - Thanchi Rd, Nilgiri, Bangladesh',21.9120,92.3253,'Day visits and stays','https://maps.google.com/?cid=15793951498546496791'),
('ahsan','Ahsan Manzil','Dhaka','Bangladesh','Heritage','Dhaka',4.4,19941,8,'The Pink Palace of the Nawabs of Dhaka, now a museum beside the Buriganga river. It mixes local and European architecture under a large central dome.','Nov to Feb','car','In Old Dhaka by the Buriganga river. Take a CNG or rickshaw from Sadarghat.','30 min',array['Entry ticket','Local guide','Parking','Guided tour']::text[],'PC54+C5M, 2/3 Islampur Rd, Dhaka 1100, Bangladesh',23.7085,90.4060,'9 AM to 6 PM, closed Thursday','https://maps.google.com/?cid=15810979282014460759'),
('kuakata','Kuakata Sea Beach','Patuakhali','Bangladesh','Beach','Dhaka',4.5,6182,40,'A wide beach where you can watch both sunrise and sunset over the sea. Quieter than the busy south-east coast, with fresh fish by the shore.','Nov to Mar','bus','Take an overnight bus or launch from Dhaka to Patuakhali, then a road transfer to Kuakata.','6 to 8 h',array['Beach access','Local guide','Meals','Transfers']::text[],'Kuakata Sea Beach, Bangladesh',21.8031,90.1823,'Open access','https://maps.google.com/?cid=224757685228233841'),
('lawachara','Lawachara National Park','Sreemangal','Bangladesh','Forest','Dhaka',4.4,6557,20,'A protected rainforest in the Sreemangal tea country, with walking trails, birds, monkeys and a railway line through the trees. Early mornings are best for wildlife.','Nov to Mar','train','Take a train from Dhaka to Sreemangal, then a short CNG ride to the park gate.','4 to 5 h',array['Boat or trail','Local guide','Permits','Meals']::text[],'Kamalganj, Bangladesh',24.3251,91.7871,'9:00 AM to 5:00 PM','https://maps.google.com/?cid=8869812032783317341'),
('sixty','Sixty Dome Mosque','Bagerhat','Bangladesh','Heritage','Khulna',4.7,9808,12,'A 15th century brick mosque built by Khan Jahan Ali in the UNESCO-listed Historic Mosque City of Bagerhat. Shady grounds and a large pond make for a calm visit.','Nov to Feb','bus','Take a bus or car from Khulna to Bagerhat, about an hour.','1 h',array['Entry ticket','Local guide','Parking','Guided tour']::text[],'Bagerhat, Bangladesh',22.6745,89.7418,'9:00 AM to 5:00 PM','https://maps.google.com/?cid=7313691277640162727')
on conflict (id) do update set
 name=excluded.name, location=excluded.location, country=excluded.country, category=excluded.category, hub=excluded.hub,
 rating=excluded.rating, reviews=excluded.reviews, price=excluded.price, about=excluded.about, season=excluded.season,
 last_mode=excluded.last_mode, last_detail=excluded.last_detail, last_duration=excluded.last_duration, facilities=excluded.facilities,
 address=excluded.address, lat=excluded.lat, lng=excluded.lng, hours=excluded.hours, maps_url=excluded.maps_url;

insert into public.guides (id,name,base,bio,rating,price_per_day,years,languages) values
 ('g1','Rahim Uddin','Bangladesh','Hill-tracts specialist. Knows every boat route on Kaptai Lake and the safest jeep drivers to Sajek.',4.9,35,8,array['Bangla','English']),
 ('g2','Pema Sherpa','Nepal','Licensed trekking guide. Eleven Kanchenjunga expeditions, wilderness first-aid certified.',5.0,60,14,array['Nepali','English','Hindi']),
 ('g3','Yuki Tanaka','Japan','Kyoto native. Temple etiquette, hidden tea houses and seasonal photo spots.',4.8,90,6,array['Japanese','English']),
 ('g4','Andi Pratama','Indonesia','Divemaster and boat captain based in Waisai. Plans island-hopping around the weather.',4.8,45,9,array['Indonesian','English']),
 ('g5','Lucia Quispe','Peru','Archaeology graduate who leads Inca Trail groups and explains the stories behind the stones.',4.9,70,11,array['Spanish','Quechua','English']),
 ('g6','Youssef Benali','Morocco','Berber guide from Merzouga. Camel treks, dune sunrise and family-run camps.',4.7,50,7,array['Arabic','French','English']),
 ('g7','Eleni Katsaros','Greece','Local historian offering caldera walks, winery visits and quiet beaches.',4.8,65,5,array['Greek','English'])
on conflict (id) do nothing;

-- ============ PROFILE EDITING ============
grant update (name, username, avatar_url, bio, home, cover_url, countries, next_place_id) on public.profiles to authenticated;

-- ============ REAL PLACE PHOTOS FROM WIKIPEDIA ============
update public.places p set wiki_title = v.t from (values
 ('raja','Raja_Ampat_Islands'),('kaptai','Kaptai_Lake'),('sajek','Sajek_Valley'),('kyoto','Fushimi_Inari-taisha'),
 ('machu','Machu_Picchu'),('cox','Cox''s_Bazar_Beach'),('stm','St._Martin''s_Island'),('karamjal','Sundarbans'),
 ('ratargul','Ratargul_Swamp_Forest'),('jaflong','Jaflong'),('nilgiri','Bandarban_District'),('ahsan','Ahsan_Manzil'),
 ('kuakata','Kuakata'),('lawachara','Lawachara_National_Park'),('sixty','Sixty_Dome_Mosque')
) as v(id, t) where p.id = v.id;

create extension if not exists http with schema extensions;

do $$
declare r record; j jsonb; thumb text; orig text; w int;
begin
  for r in select id, wiki_title from public.places where image_url is null and wiki_title is not null loop
    begin
      select content::jsonb into j from extensions.http_get('https://en.wikipedia.org/api/rest_v1/page/summary/' || r.wiki_title);
      thumb := j->'thumbnail'->>'source';
      orig  := j->'originalimage'->>'source';
      w     := coalesce((j->'originalimage'->>'width')::int, 0);
      update public.places
         set image_url = case when w > 1280 and thumb is not null then regexp_replace(thumb, '/[0-9]+px-', '/1280px-') else coalesce(orig, thumb) end
       where id = r.id;
    exception when others then
      raise notice 'photo lookup failed for %', r.id;
    end;
  end loop;
end $$;

select id, name, image_url is not null as has_photo from public.places order by id;
