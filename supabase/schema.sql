-- Reference for the already-applied create_private_sandbox_profiles migration.
create table public.sandbox_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 80),
  created_at timestamptz not null default now()
);
alter table public.sandbox_profiles enable row level security;
revoke all on public.sandbox_profiles from anon, authenticated;
grant select on public.sandbox_profiles to authenticated;
grant insert (id, display_name) on public.sandbox_profiles to authenticated;
grant update (display_name) on public.sandbox_profiles to authenticated;
create policy own_profile_select on public.sandbox_profiles for select to authenticated using ((select auth.uid()) = id);
create policy own_profile_insert on public.sandbox_profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy own_profile_update on public.sandbox_profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
