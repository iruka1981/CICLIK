create table if not exists public.member_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  contribution_types text[] not null default '{}',
  contribution_notes text,
  interest_types text[] not null default '{}',
  interest_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.member_profiles enable row level security;

drop policy if exists "Members can view their own profile" on public.member_profiles;
create policy "Members can view their own profile"
  on public.member_profiles for select
  using (auth.uid() = user_id);

drop policy if exists "Members can create their own profile" on public.member_profiles;
create policy "Members can create their own profile"
  on public.member_profiles for insert
  with check (auth.uid() = user_id);

drop policy if exists "Members can update their own profile" on public.member_profiles;
create policy "Members can update their own profile"
  on public.member_profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.set_member_profiles_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_member_profiles_updated_at on public.member_profiles;
create trigger set_member_profiles_updated_at
before update on public.member_profiles
for each row execute function public.set_member_profiles_updated_at();
