
create schema kina_private;
revoke all on schema kina_private from public, anon, authenticated;
grant usage on schema kina_private to authenticated;

create table public.cloud_demo_wallets (
 user_id uuid primary key references auth.users(id) on delete cascade,
 balance_toea bigint not null default 0 check (balance_toea between 0 and 1000000000),
 created_at timestamptz not null default now()
);
create table public.cloud_demo_transactions (
 user_id uuid not null references public.cloud_demo_wallets(user_id) on delete cascade,
 request_id uuid not null,
 sequence bigint generated always as identity,
 kind text not null check (kind in ('received','sent','electricity','water','rent','mobile')),
 title text not null check (char_length(title) between 1 and 160),
 detail text not null check (char_length(detail) between 1 and 500),
 amount_toea bigint not null check (abs(amount_toea) between 1 and 1000000),
 created_at timestamptz not null default now(),
 primary key (user_id, request_id),
 check ((kind = 'received' and amount_toea > 0) or (kind <> 'received' and amount_toea < 0))
);
create index cloud_demo_transactions_history on public.cloud_demo_transactions(user_id, sequence desc);
alter table public.cloud_demo_wallets enable row level security;
alter table public.cloud_demo_transactions enable row level security;
revoke all on public.cloud_demo_wallets, public.cloud_demo_transactions from anon, authenticated;
grant select on public.cloud_demo_wallets, public.cloud_demo_transactions to authenticated;
create policy own_cloud_wallet_read on public.cloud_demo_wallets for select to authenticated using ((select auth.uid()) = user_id);
create policy own_cloud_history_read on public.cloud_demo_transactions for select to authenticated using ((select auth.uid()) = user_id);

-- A private, narrowly scoped writer is required: clients must not update balances
-- or insert arbitrary ledger rows directly. No caller-provided owner ID is used.
create function kina_private.cloud_wallet(p_request_id uuid default null,
 p_kind text default null, p_title text default null, p_detail text default null,
 p_amount_toea bigint default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_user uuid := auth.uid();
 v_balance bigint;
 v_prior public.cloud_demo_transactions%rowtype;
begin
 if v_user is null or not exists (
   select 1 from auth.users where id = v_user and email_confirmed_at is not null
   and coalesce(is_anonymous, false) = false
 ) then
   raise exception 'Confirmed account required' using errcode='28000';
 end if;

 insert into public.cloud_demo_wallets(user_id) values(v_user) on conflict do nothing;
 select balance_toea into v_balance from public.cloud_demo_wallets
 where user_id=v_user for update;

 if p_request_id is not null then
   if p_kind is null or p_kind not in ('received','sent','electricity','water','rent','mobile')
     or p_amount_toea is null or p_amount_toea not between -1000000 and 1000000
     or p_amount_toea = 0
     or (p_kind='received') <> (p_amount_toea > 0)
     or p_title is null or char_length(btrim(p_title)) not between 1 and 160
     or p_detail is null or char_length(btrim(p_detail)) not between 1 and 500 then
     raise exception 'Invalid demo transaction' using errcode='22023';
   end if;
   select * into v_prior from public.cloud_demo_transactions
     where user_id=v_user and request_id=p_request_id;
   if found then
     if v_prior.kind <> p_kind or v_prior.title <> p_title
       or v_prior.detail <> p_detail or v_prior.amount_toea <> p_amount_toea then
       raise exception 'Request already used with different details' using errcode='22023';
     end if;
   else
     if v_balance+p_amount_toea < 0 then
       raise exception 'Insufficient demo balance' using errcode='P0001';
     end if;
     if v_balance+p_amount_toea > 1000000000 then
       raise exception 'Demo balance limit reached' using errcode='22023';
     end if;
     insert into public.cloud_demo_transactions(user_id,request_id,kind,title,detail,amount_toea)
       values(v_user,p_request_id,p_kind,p_title,p_detail,p_amount_toea);
     v_balance := v_balance+p_amount_toea;
     update public.cloud_demo_wallets set balance_toea=v_balance where user_id=v_user;
   end if;
 elsif p_kind is not null or p_title is not null or p_detail is not null or p_amount_toea is not null then
   raise exception 'Request ID required' using errcode='22023';
 end if;
 return jsonb_build_object('balanceToea',v_balance,'transactions',coalesce((
   select jsonb_agg(jsonb_build_object(
     'title',title,'detail',detail,'amountToea',amount_toea,'icon',kind,
     'createdAt',created_at,'reference','CLOUD-DEMO-' || request_id::text
   ) order by sequence desc) from public.cloud_demo_transactions where user_id=v_user
 ),'[]'::jsonb));
end $$;
revoke all on function kina_private.cloud_wallet(uuid,text,text,text,bigint) from public, anon, authenticated;
grant execute on function kina_private.cloud_wallet(uuid,text,text,text,bigint) to authenticated;

create function public.cloud_demo_snapshot() returns jsonb
 language sql security invoker set search_path = '' as $$
 select kina_private.cloud_wallet();
$$;
create function public.post_cloud_demo_transaction(p_request_id uuid,p_kind text,
 p_title text,p_detail text,p_amount_toea bigint) returns jsonb
 language sql security invoker set search_path = '' as $$
 select kina_private.cloud_wallet(p_request_id,p_kind,p_title,p_detail,p_amount_toea);
$$;
revoke all on function public.cloud_demo_snapshot() from public, anon, authenticated;
revoke all on function public.post_cloud_demo_transaction(uuid,text,text,text,bigint) from public, anon, authenticated;
grant execute on function public.cloud_demo_snapshot() to authenticated;
grant execute on function public.post_cloud_demo_transaction(uuid,text,text,text,bigint) to authenticated;

-- Follow-up migration: bind requests to expected account.

drop function public.cloud_demo_snapshot();
drop function public.post_cloud_demo_transaction(uuid,text,text,text,bigint);
create function public.cloud_demo_snapshot(p_expected_user uuid) returns jsonb
 language plpgsql security invoker set search_path = '' as $$
 begin
 if p_expected_user is distinct from auth.uid() or p_expected_user is null then
   raise exception 'Active account changed' using errcode='28000';
 end if;
 return kina_private.cloud_wallet();
 end $$;
create function public.post_cloud_demo_transaction(p_expected_user uuid,p_request_id uuid,p_kind text,
 p_title text,p_detail text,p_amount_toea bigint) returns jsonb
 language plpgsql security invoker set search_path = '' as $$
 begin
 if p_expected_user is distinct from auth.uid() or p_expected_user is null then
   raise exception 'Active account changed' using errcode='28000';
 end if;
 return kina_private.cloud_wallet(p_request_id,p_kind,p_title,p_detail,p_amount_toea);
 end $$;
revoke all on function public.cloud_demo_snapshot(uuid) from public, anon, authenticated;
revoke all on function public.post_cloud_demo_transaction(uuid,uuid,text,text,text,bigint) from public, anon, authenticated;
grant execute on function public.cloud_demo_snapshot(uuid) to authenticated;
grant execute on function public.post_cloud_demo_transaction(uuid,uuid,text,text,text,bigint) to authenticated;
