-- Plim: Destaques de empresas
-- Execute no SQL Editor do Supabase antes de publicar a versão com Destaques.

create table if not exists public.company_stories (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  media_url text not null,
  expires_at timestamptz not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists company_stories_city_feed_idx
  on public.company_stories (active, expires_at desc);

create index if not exists company_stories_company_created_idx
  on public.company_stories (company_id, created_at desc);

alter table public.company_stories enable row level security;

drop policy if exists "Public can view active unexpired company stories" on public.company_stories;
create policy "Public can view active unexpired company stories"
on public.company_stories for select
to anon, authenticated
using (
  active = true
  and expires_at > now()
  and exists (
    select 1 from public.companies c
    where c.id = company_stories.company_id
      and c.active = true
  )
);

drop policy if exists "Company owners can manage their stories" on public.company_stories;
create policy "Company owners can manage their stories"
on public.company_stories for all
to authenticated
using (
  exists (
    select 1 from public.companies c
    where c.id = company_stories.company_id
      and c.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.companies c
    where c.id = company_stories.company_id
      and c.owner_id = auth.uid()
  )
);
