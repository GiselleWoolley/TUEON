-- =====================================================================
-- Diário da Gira · script do banco (Supabase)
-- Cole tudo no SQL Editor do Supabase e clique em "Run".
-- ANTES de rodar, troque o e-mail da dirigente na última seção.
-- =====================================================================

-- ---------- Tabelas ----------------------------------------------------

create table if not exists public.turmas (
  id         uuid primary key default gen_random_uuid(),
  nome       text not null check (char_length(nome) between 1 and 80),
  criado_em  timestamptz not null default now()
);

create table if not exists public.perfis (
  id         uuid primary key references auth.users(id) on delete cascade,
  nome       text not null default '',
  email      text not null,
  papel      text not null default 'cursista' check (papel in ('dirigente','cursista')),
  criado_em  timestamptz not null default now()
);

create table if not exists public.convites (
  email      text primary key check (email = lower(email)),
  nome       text not null default '',
  papel      text not null default 'cursista' check (papel in ('dirigente','cursista')),
  turma_id   uuid references public.turmas(id) on delete set null,
  criado_por uuid references public.perfis(id) on delete set null,
  criado_em  timestamptz not null default now(),
  usado_em   timestamptz
);

create table if not exists public.membros (
  turma_id   uuid not null references public.turmas(id) on delete cascade,
  user_id    uuid not null references public.perfis(id) on delete cascade,
  primary key (turma_id, user_id)
);

-- Diário pessoal: só a própria pessoa lê e escreve.
create table if not exists public.registros (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references public.perfis(id) on delete cascade,
  dados      jsonb not null,
  criado_em  timestamptz not null default now()
);

-- Roda de partilha da turma. autor_id vazio = partilhado sem nome.
create table if not exists public.roda (
  id          uuid primary key default gen_random_uuid(),
  turma_id    uuid not null references public.turmas(id) on delete cascade,
  registro_id uuid not null references public.registros(id) on delete cascade,
  autor_id    uuid references public.perfis(id) on delete set null,
  dados       jsonb not null,
  criado_em   timestamptz not null default now()
);

create table if not exists public.acolhimentos (
  id         uuid primary key default gen_random_uuid(),
  roda_id    uuid not null references public.roda(id) on delete cascade,
  autor_id   uuid not null default auth.uid() references public.perfis(id) on delete cascade,
  texto      text not null check (char_length(texto) between 1 and 300),
  criado_em  timestamptz not null default now()
);

-- Caderno da turma: sempre anônimo.
create table if not exists public.caderno (
  id          uuid primary key default gen_random_uuid(),
  turma_id    uuid not null references public.turmas(id) on delete cascade,
  registro_id uuid not null references public.registros(id) on delete cascade,
  dados       jsonb not null,
  criado_em   timestamptz not null default now()
);

create index if not exists roda_turma_idx     on public.roda(turma_id, criado_em desc);
create index if not exists caderno_turma_idx  on public.caderno(turma_id);
create index if not exists registros_user_idx on public.registros(user_id, criado_em desc);
create index if not exists acolh_roda_idx     on public.acolhimentos(roda_id, criado_em);

-- ---------- Funções auxiliares (usadas pelas regras de acesso) --------

create or replace function public.eh_dirigente() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from perfis where id = auth.uid() and papel = 'dirigente');
$$;

create or replace function public.eh_membro(t uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from membros where turma_id = t and user_id = auth.uid());
$$;

create or replace function public.compartilha_turma(u uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from membros a join membros b on a.turma_id = b.turma_id
    where a.user_id = auth.uid() and b.user_id = u
  );
$$;

create or replace function public.meu_registro(r uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from registros where id = r and user_id = auth.uid());
$$;

-- Usada na tela de "Primeiro acesso" para avisar se o e-mail foi convidado.
create or replace function public.convite_existe(e text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from convites where email = lower(trim(e)) and usado_em is null);
$$;

-- Só a dirigente muda o papel de alguém.
create or replace function public.definir_papel(alvo uuid, novo text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.eh_dirigente() then raise exception 'Apenas a dirigente pode mudar papéis.'; end if;
  if novo not in ('dirigente','cursista') then raise exception 'Papel inválido.'; end if;
  if alvo = auth.uid() and novo = 'cursista'
     and (select count(*) from perfis where papel = 'dirigente') <= 1 then
    raise exception 'O app precisa de pelo menos uma pessoa dirigente.';
  end if;
  update perfis set papel = novo where id = alvo;
end $$;

-- ---------- Cadastro só para quem foi convidado ------------------------

create or replace function public.novo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
declare c public.convites%rowtype;
begin
  select * into c from public.convites where email = lower(new.email) and usado_em is null;
  if not found then
    raise exception 'Este e-mail não foi convidado. Peça um convite à dirigente.';
  end if;
  insert into public.perfis (id, nome, email, papel)
  values (new.id,
          coalesce(nullif(trim(new.raw_user_meta_data->>'nome'), ''), nullif(c.nome, ''), split_part(new.email, '@', 1)),
          lower(new.email), c.papel);
  if c.turma_id is not null then
    insert into public.membros (turma_id, user_id) values (c.turma_id, new.id) on conflict do nothing;
  end if;
  update public.convites set usado_em = now() where email = c.email;
  return new;
end $$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario after insert on auth.users
  for each row execute function public.novo_usuario();

-- ---------- Regras de acesso (RLS) -------------------------------------

alter table public.turmas       enable row level security;
alter table public.perfis       enable row level security;
alter table public.convites     enable row level security;
alter table public.membros      enable row level security;
alter table public.registros    enable row level security;
alter table public.roda         enable row level security;
alter table public.acolhimentos enable row level security;
alter table public.caderno      enable row level security;

-- Perfis: cada um vê o seu, quem divide turma e a dirigente vê todos.
drop policy if exists perfis_ler on public.perfis;
create policy perfis_ler on public.perfis for select to authenticated
  using (id = auth.uid() or public.eh_dirigente() or public.compartilha_turma(id));
drop policy if exists perfis_editar on public.perfis;
create policy perfis_editar on public.perfis for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.perfis from authenticated;
grant update (nome) on public.perfis to authenticated;

-- Convites: só a dirigente.
drop policy if exists convites_dirigente on public.convites;
create policy convites_dirigente on public.convites for all to authenticated
  using (public.eh_dirigente()) with check (public.eh_dirigente());

-- Turmas: membros leem; dirigente gerencia.
drop policy if exists turmas_ler on public.turmas;
create policy turmas_ler on public.turmas for select to authenticated
  using (public.eh_dirigente() or public.eh_membro(id));
drop policy if exists turmas_gerir on public.turmas;
create policy turmas_gerir on public.turmas for all to authenticated
  using (public.eh_dirigente()) with check (public.eh_dirigente());

-- Membros: quem está na turma vê a lista; dirigente gerencia.
drop policy if exists membros_ler on public.membros;
create policy membros_ler on public.membros for select to authenticated
  using (public.eh_dirigente() or user_id = auth.uid() or public.eh_membro(turma_id));
drop policy if exists membros_gerir on public.membros;
create policy membros_gerir on public.membros for all to authenticated
  using (public.eh_dirigente()) with check (public.eh_dirigente());

-- Diário: privado, nem a dirigente vê.
drop policy if exists registros_dono on public.registros;
create policy registros_dono on public.registros for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Roda: a turma lê; cada um partilha o próprio registro.
drop policy if exists roda_ler on public.roda;
create policy roda_ler on public.roda for select to authenticated
  using (public.eh_dirigente() or public.eh_membro(turma_id));
drop policy if exists roda_criar on public.roda;
create policy roda_criar on public.roda for insert to authenticated
  with check ((public.eh_membro(turma_id) or public.eh_dirigente())
              and public.meu_registro(registro_id)
              and (autor_id is null or autor_id = auth.uid()));
drop policy if exists roda_apagar on public.roda;
create policy roda_apagar on public.roda for delete to authenticated
  using (public.meu_registro(registro_id) or public.eh_dirigente());

-- Acolhimentos: quem vê o relato pode acolher.
drop policy if exists acolh_ler on public.acolhimentos;
create policy acolh_ler on public.acolhimentos for select to authenticated
  using (exists (select 1 from public.roda r where r.id = roda_id));
drop policy if exists acolh_criar on public.acolhimentos;
create policy acolh_criar on public.acolhimentos for insert to authenticated
  with check (autor_id = auth.uid() and exists (select 1 from public.roda r where r.id = roda_id));
drop policy if exists acolh_apagar on public.acolhimentos;
create policy acolh_apagar on public.acolhimentos for delete to authenticated
  using (autor_id = auth.uid() or public.eh_dirigente());

-- Caderno: a turma lê; cada um contribui com o próprio registro.
drop policy if exists caderno_ler on public.caderno;
create policy caderno_ler on public.caderno for select to authenticated
  using (public.eh_dirigente() or public.eh_membro(turma_id));
drop policy if exists caderno_criar on public.caderno;
create policy caderno_criar on public.caderno for insert to authenticated
  with check ((public.eh_membro(turma_id) or public.eh_dirigente()) and public.meu_registro(registro_id));
drop policy if exists caderno_apagar on public.caderno;
create policy caderno_apagar on public.caderno for delete to authenticated
  using (public.meu_registro(registro_id) or public.eh_dirigente());

grant execute on function public.convite_existe(text) to anon, authenticated;
grant execute on function public.definir_papel(uuid, text) to authenticated;

-- ---------- Primeira dirigente -----------------------------------------
-- Troque pelo SEU e-mail (em letras minúsculas) e pelo seu nome.
insert into public.convites (email, nome, papel)
values ('seu-email@exemplo.com', 'Seu nome', 'dirigente')
on conflict (email) do update set papel = 'dirigente', usado_em = null;
