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
