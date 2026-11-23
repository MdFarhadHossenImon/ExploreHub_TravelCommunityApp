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
