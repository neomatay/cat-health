-- ============================================================
-- 猫咪健康 PWA - Supabase 建表脚本
-- ============================================================
-- 在 Supabase Dashboard → SQL Editor 中执行此脚本。
-- family_id 即"家庭密码"：创建家庭时生成一个 UUID 作为 family_id，
-- 所有数据均带此列。个人家庭项目使用宽松 RLS 策略（anon 全部读写）。
-- 注意：这意味着知道 family_id 即可访问对应数据，不适合敏感场景。
-- ============================================================

create extension if not exists "pgcrypto";

-- 猫咪表
create table if not exists cats (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null,
  name text not null,
  breed text,
  birthday date,
  created_at timestamptz default now()
);

-- 体重记录表
create table if not exists weights (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null,
  cat_id uuid not null,
  date date not null,
  kg numeric not null check (kg > 0 and kg < 50),
  note text,
  created_at timestamptz default now()
);
create index if not exists idx_weights_cat_date on weights (cat_id, date desc);

-- 体温记录表
create table if not exists temps (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null,
  cat_id uuid not null,
  date date not null,
  celsius numeric not null check (celsius > 30 and celsius < 45),
  note text,
  created_at timestamptz default now()
);
create index if not exists idx_temps_cat_date on temps (cat_id, date desc);

-- 用药计划表
create table if not exists med_plans (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null,
  cat_id uuid not null,
  drug text not null,
  dose text,
  remind_times text[] not null default '{}',
  start_date date not null,
  end_date date,
  active boolean default true,
  note text,
  created_at timestamptz default now()
);
create index if not exists idx_med_plans_cat on med_plans (cat_id);

-- 用药打卡记录表
create table if not exists med_logs (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null,
  plan_id uuid not null,
  cat_id uuid not null,
  date date not null,
  scheduled_time text not null,
  status text not null default 'missed', -- taken | skipped | missed
  taken_at timestamptz,
  note text,
  created_at timestamptz default now(),
  unique (plan_id, date, scheduled_time)
);
create index if not exists idx_med_logs_plan_date on med_logs (plan_id, date);

-- ============================================================
-- 启用行级安全 RLS
-- ============================================================
alter table cats enable row level security;
alter table weights enable row level security;
alter table temps enable row level security;
alter table med_plans enable row level security;
alter table med_logs enable row level security;

-- 宽松策略：anon 角色可全部读写所有行
-- family_id 作为访问凭证，前端在查询/写入时带上 family_id 过滤
create policy "cats all"   on cats     for all to anon using (true) with check (true);
create policy "weights all" on weights  for all to anon using (true) with check (true);
create policy "temps all"  on temps    for all to anon using (true) with check (true);
create policy "med_plans all" on med_plans for all to anon using (true) with check (true);
create policy "med_logs all" on med_logs  for all to anon using (true) with check (true);
