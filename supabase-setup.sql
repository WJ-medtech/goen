-- ============================================================
--  GOEN : Supabase テーブル作成スクリプト
--  Supabase の「SQL Editor」に全部コピペして Run するだけでOK。
--  何度実行しても壊れないようになっています。
-- ============================================================

-- 1) 大項目：大学・科 -----------------------------------------
create table if not exists public.categories (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name        text not null,
  sort_order  int  not null default 0,
  created_at  timestamptz not null default now()
);

-- 2) 中項目：病院 ---------------------------------------------
create table if not exists public.hospitals (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  name        text not null,
  sort_order  int  not null default 0,
  created_at  timestamptz not null default now()
);

-- 3) 小項目の定義（項目名のリスト） ---------------------------
create table if not exists public.fields (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  label       text not null,
  sort_order  int  not null default 0,
  created_at  timestamptz not null default now()
);

-- 4) 記入内容（病院 × 小項目） --------------------------------
create table if not exists public.entries (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  hospital_id uuid not null references public.hospitals(id) on delete cascade,
  field_id    uuid not null references public.fields(id)    on delete cascade,
  value       text not null default '',
  updated_at  timestamptz not null default now(),
  unique (hospital_id, field_id)
);

-- 検索を速くするための索引 -------------------------------------
create index if not exists idx_hospitals_cat  on public.hospitals(category_id);
create index if not exists idx_entries_hosp   on public.entries(hospital_id);
create index if not exists idx_entries_field  on public.entries(field_id);
create index if not exists idx_cat_user       on public.categories(user_id);

-- ============================================================
--  RLS（行レベルセキュリティ）
--  「自分のデータしか読めない・書けない」ようにする設定。
--  必ず有効にしてください。
-- ============================================================
alter table public.categories enable row level security;
alter table public.hospitals  enable row level security;
alter table public.fields     enable row level security;
alter table public.entries    enable row level security;

do $$
declare t text;
begin
  foreach t in array array['categories','hospitals','fields','entries'] loop
    execute format('drop policy if exists own_select on public.%I', t);
    execute format('drop policy if exists own_insert on public.%I', t);
    execute format('drop policy if exists own_update on public.%I', t);
    execute format('drop policy if exists own_delete on public.%I', t);

    execute format('create policy own_select on public.%I for select using (auth.uid() = user_id)', t);
    execute format('create policy own_insert on public.%I for insert with check (auth.uid() = user_id)', t);
    execute format('create policy own_update on public.%I for update using (auth.uid() = user_id) with check (auth.uid() = user_id)', t);
    execute format('create policy own_delete on public.%I for delete using (auth.uid() = user_id)', t);
  end loop;
end $$;

-- 完了。
-- 初期データ（京大／公立大 糖尿病内分泌 と 小項目18個）は
-- 最初にアプリへログインした時に自動で作られます。
