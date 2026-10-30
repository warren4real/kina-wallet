
alter table public.sandbox_profiles add column phone_number text
 check (phone_number is null or phone_number ~ '^[0-9]{8}$');
grant insert (phone_number), update (phone_number) on public.sandbox_profiles to authenticated;
create table public.cloud_demo_recipients (
 user_id uuid not null references auth.users(id) on delete cascade,
 phone_number text not null check (phone_number ~ '^[0-9]{8}$'),
 name text not null check (char_length(btrim(name)) between 1 and 80),
 created_at timestamptz not null default now(),
 primary key(user_id,phone_number)
);
alter table public.cloud_demo_recipients enable row level security;
revoke all on public.cloud_demo_recipients from anon, authenticated;
grant select, delete on public.cloud_demo_recipients to authenticated;
grant insert(user_id,phone_number,name), update(phone_number,name) on public.cloud_demo_recipients to authenticated;
create policy own_recipients_select on public.cloud_demo_recipients for select to authenticated using ((select auth.uid()) = user_id);
create policy own_recipients_insert on public.cloud_demo_recipients for insert to authenticated with check ((select auth.uid()) = user_id);
create policy own_recipients_update on public.cloud_demo_recipients for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy own_recipients_delete on public.cloud_demo_recipients for delete to authenticated using ((select auth.uid()) = user_id);
