-- Contagem de aberturas de ofertas e destaques, sem armazenar dados pessoais.
create table if not exists public.publication_views (
  id bigint generated always as identity primary key,
  publication_type text not null check (publication_type in ('offer', 'story')),
  publication_id uuid not null,
  viewed_at timestamptz not null default now()
);

create index if not exists publication_views_publication_idx
  on public.publication_views (publication_type, publication_id);

alter table public.publication_views enable row level security;
revoke all on public.publication_views from anon, authenticated;

create or replace function public.record_publication_view(
  p_publication_type text,
  p_publication_id uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  is_visible boolean := false;
begin
  if p_publication_type = 'offer' then
    select exists (
      select 1 from public.company_offers o
      join public.companies c on c.id = o.company_id
      where o.id = p_publication_id and o.active = true and c.active = true
        and (o.starts_at is null or o.starts_at <= now())
        and (o.ends_at is null or o.ends_at >= now())
    ) into is_visible;
  elsif p_publication_type = 'story' then
    select exists (
      select 1 from public.company_stories s
      join public.companies c on c.id = s.company_id
      where s.id = p_publication_id and s.active = true and s.expires_at > now()
        and c.active = true
    ) into is_visible;
  else
    raise exception 'Tipo de publicação inválido';
  end if;

  if is_visible then
    insert into public.publication_views(publication_type, publication_id)
    values (p_publication_type, p_publication_id);
  end if;
end;
$$;

create or replace function public.get_company_publication_view_counts(p_company_id uuid)
returns table(publication_type text, publication_id uuid, views bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.companies c
    where c.id = p_company_id and c.owner_id = auth.uid()
  ) then
    raise exception 'Acesso não autorizado';
  end if;

  return query
    select v.publication_type, v.publication_id, count(*)::bigint
    from public.publication_views v
    where (v.publication_type = 'offer' and exists (
      select 1 from public.company_offers o
      where o.id = v.publication_id and o.company_id = p_company_id
    )) or (v.publication_type = 'story' and exists (
      select 1 from public.company_stories s
      where s.id = v.publication_id and s.company_id = p_company_id
    ))
    group by v.publication_type, v.publication_id;
end;
$$;

revoke all on function public.record_publication_view(text, uuid) from public;
grant execute on function public.record_publication_view(text, uuid) to anon, authenticated;
revoke all on function public.get_company_publication_view_counts(uuid) from public, anon;
grant execute on function public.get_company_publication_view_counts(uuid) to authenticated;
