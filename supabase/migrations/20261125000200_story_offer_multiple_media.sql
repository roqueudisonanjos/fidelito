-- Suporte a galerias (até 5 mídias) e texto nos destaques.
alter table public.company_stories
  add column if not exists description text,
  add column if not exists media_urls jsonb not null default '[]'::jsonb;

update public.company_stories
set media_urls = jsonb_build_array(media_url)
where media_urls = '[]'::jsonb and media_url is not null;

alter table public.company_offers
  add column if not exists media_urls jsonb not null default '[]'::jsonb;

update public.company_offers
set media_urls = jsonb_build_array(image_url)
where media_urls = '[]'::jsonb and image_url is not null;

-- Limite estrutural adicional: no máximo cinco URLs por registro.
alter table public.company_stories drop constraint if exists company_stories_media_urls_limit;
alter table public.company_stories add constraint company_stories_media_urls_limit
  check (jsonb_typeof(media_urls) = 'array' and jsonb_array_length(media_urls) <= 5);

alter table public.company_offers drop constraint if exists company_offers_media_urls_limit;
alter table public.company_offers add constraint company_offers_media_urls_limit
  check (jsonb_typeof(media_urls) = 'array' and jsonb_array_length(media_urls) <= 5);

alter table public.promotions add column if not exists media_urls jsonb not null default '[]'::jsonb;
update public.promotions set media_urls = jsonb_build_array(image_url) where media_urls = '[]'::jsonb and image_url is not null;
alter table public.promotions drop constraint if exists promotions_media_urls_limit;
alter table public.promotions add constraint promotions_media_urls_limit check (jsonb_typeof(media_urls) = 'array' and jsonb_array_length(media_urls) <= 5);
