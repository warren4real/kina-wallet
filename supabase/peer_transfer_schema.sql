
alter table public.cloud_demo_transactions add column transfer_id uuid,
 add column counterparty_id uuid,
 add constraint transfer_pair_metadata check ((transfer_id is null) = (counterparty_id is null)),
 add constraint transfer_other_account check (counterparty_id is null or counterparty_id <> user_id);
create unique index unique_cloud_transfer_leg on public.cloud_demo_transactions(user_id,transfer_id) where transfer_id is not null;
alter table public.cloud_demo_recipients add column receiving_account_id uuid references auth.users(id) on delete set null;
grant insert(receiving_account_id),update(receiving_account_id) on public.cloud_demo_recipients to authenticated;

create or replace function kina_private.cloud_wallet(p_request_id uuid default null,
 p_kind text default null,p_title text default null,p_detail text default null,p_amount_toea bigint default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_user uuid:=auth.uid();v_balance bigint;v_prior public.cloud_demo_transactions%rowtype;
begin
 if v_user is null or not exists(select 1 from auth.users where id=v_user and email_confirmed_at is not null and coalesce(is_anonymous,false)=false)
 then raise exception 'Confirmed account required' using errcode='28000';end if;
 insert into public.cloud_demo_wallets(user_id) values(v_user) on conflict do nothing;
 select balance_toea into v_balance from public.cloud_demo_wallets where user_id=v_user for update;
 if p_request_id is not null then
  if p_kind is null or p_kind not in ('received','sent','electricity','water','rent','mobile')
   or p_amount_toea is null or p_amount_toea not between -1000000 and 1000000 or p_amount_toea=0
   or (p_kind='received')<>(p_amount_toea>0)
   or p_title is null or char_length(btrim(p_title)) not between 1 and 160
   or p_detail is null or char_length(btrim(p_detail)) not between 1 and 500
  then raise exception 'Invalid demo transaction' using errcode='22023';end if;
  select * into v_prior from public.cloud_demo_transactions where user_id=v_user and request_id=p_request_id;
  if found then
   if v_prior.transfer_id is not null or v_prior.kind<>p_kind or v_prior.title<>p_title
    or v_prior.detail<>p_detail or v_prior.amount_toea<>p_amount_toea
   then raise exception 'Request already used' using errcode='22023';end if;
  else
   if p_kind='sent' then raise exception 'Use an account-to-account demo transfer' using errcode='22023';end if;
   if v_balance+p_amount_toea<0 then raise exception 'Insufficient demo balance' using errcode='P0001';end if;
   if v_balance+p_amount_toea>1000000000 then raise exception 'Demo balance limit reached' using errcode='22003';end if;
   insert into public.cloud_demo_transactions(user_id,request_id,kind,title,detail,amount_toea)
    values(v_user,p_request_id,p_kind,p_title,p_detail,p_amount_toea);
   v_balance:=v_balance+p_amount_toea;
   update public.cloud_demo_wallets set balance_toea=v_balance where user_id=v_user;
  end if;
 elsif p_kind is not null or p_title is not null or p_detail is not null or p_amount_toea is not null
 then raise exception 'Request ID required' using errcode='22023';end if;
 return jsonb_build_object('balanceToea',v_balance,'transactions',coalesce((
  select jsonb_agg(jsonb_build_object('title',title,'detail',detail,'amountToea',amount_toea,
   'icon',kind,'createdAt',created_at,'reference',
   case when transfer_id is null then 'CLOUD-DEMO-'||request_id::text else 'CLOUD-TRANSFER-'||transfer_id::text end
  ) order by sequence desc) from public.cloud_demo_transactions where user_id=v_user
 ),'[]'::jsonb));
end $$;

create function kina_private.find_demo_recipient(p_expected_user uuid,p_recipient uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_name text;
begin
 if p_expected_user is null or p_expected_user is distinct from auth.uid()
  or not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null and coalesce(is_anonymous,false)=false)
 then raise exception 'Confirmed account required' using errcode='28000';end if;
 if p_recipient is null or p_recipient=p_expected_user then raise exception 'Choose another demo account' using errcode='22023';end if;
 select p.display_name into v_name from public.sandbox_profiles p join auth.users u on u.id=p.id
 where p.id=p_recipient and u.email_confirmed_at is not null and coalesce(u.is_anonymous,false)=false;
 if not found then raise exception 'Demo recipient not found' using errcode='P0002';end if;
 return jsonb_build_object('accountId',p_recipient,'displayName',v_name);
end $$;

create function kina_private.transfer_demo(p_expected_user uuid,p_request_id uuid,p_recipient uuid,p_amount_toea bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_sender uuid:=auth.uid();v_prior public.cloud_demo_transactions%rowtype;
 v_sender_balance bigint;v_recipient_balance bigint;v_transfer uuid;v_time timestamptz;
 v_sender_name text;v_recipient_name text;
begin
 if v_sender is null or p_expected_user is distinct from v_sender
  or not exists(select 1 from auth.users where id=v_sender and email_confirmed_at is not null and coalesce(is_anonymous,false)=false)
 then raise exception 'Confirmed account required' using errcode='28000';end if;
 if p_request_id is null or p_recipient is null or p_recipient=v_sender
  or p_amount_toea is null or p_amount_toea not between 1 and 1000000
 then raise exception 'Invalid demo transfer' using errcode='22023';end if;

 -- An immutable committed sender leg is enough to recognize a retry even if
 -- the recipient later deletes their own account and wallet.
 select * into v_prior from public.cloud_demo_transactions where user_id=v_sender and request_id=p_request_id;
 if found then
  if v_prior.transfer_id is null or v_prior.kind<>'sent' or v_prior.counterparty_id<>p_recipient or v_prior.amount_toea<>-p_amount_toea
  then raise exception 'Request already used with different details' using errcode='22023';end if;
  return kina_private.cloud_wallet()||jsonb_build_object('transferReference','CLOUD-TRANSFER-'||v_prior.transfer_id::text,'transferCreatedAt',v_prior.created_at);
 end if;

 -- Deterministic ordering prevents opposing transfers from locking A/B in
 -- reverse order. Key-share locks keep either account from being deleted.
 perform 1 from auth.users where id in (v_sender,p_recipient) order by id for key share;
 perform kina_private.find_demo_recipient(v_sender,p_recipient);
 select display_name into v_sender_name from public.sandbox_profiles where id=v_sender;
 select display_name into v_recipient_name from public.sandbox_profiles where id=p_recipient;
 insert into public.cloud_demo_wallets(user_id)
  select id from auth.users where id in (v_sender,p_recipient) order by id on conflict do nothing;
 perform 1 from public.cloud_demo_wallets where user_id in (v_sender,p_recipient) order by user_id for update;

 select * into v_prior from public.cloud_demo_transactions where user_id=v_sender and request_id=p_request_id;
 if found then
  if v_prior.transfer_id is null or v_prior.kind<>'sent' or v_prior.counterparty_id<>p_recipient or v_prior.amount_toea<>-p_amount_toea
  then raise exception 'Request already used with different details' using errcode='22023';end if;
  return kina_private.cloud_wallet()||jsonb_build_object('transferReference','CLOUD-TRANSFER-'||v_prior.transfer_id::text,'transferCreatedAt',v_prior.created_at);
 end if;
 select balance_toea into v_sender_balance from public.cloud_demo_wallets where user_id=v_sender;
 select balance_toea into v_recipient_balance from public.cloud_demo_wallets where user_id=p_recipient;
 if v_sender_balance<p_amount_toea then raise exception 'Insufficient demo balance' using errcode='P0001';end if;
 if v_recipient_balance+p_amount_toea>1000000000 then raise exception 'Recipient demo balance limit reached' using errcode='22003';end if;
 v_transfer:=gen_random_uuid();v_time:=clock_timestamp();
 update public.cloud_demo_wallets set balance_toea=balance_toea-p_amount_toea where user_id=v_sender;
 update public.cloud_demo_wallets set balance_toea=balance_toea+p_amount_toea where user_id=p_recipient;
 insert into public.cloud_demo_transactions(user_id,request_id,kind,title,detail,amount_toea,created_at,transfer_id,counterparty_id)
 values
 (v_sender,p_request_id,'sent','Sent to '||v_recipient_name,'Cloud demo transfer · Fictional funds',-p_amount_toea,v_time,v_transfer,p_recipient),
 (p_recipient,gen_random_uuid(),'received','Received from '||coalesce(v_sender_name,'Test account'),'Cloud demo transfer · Fictional funds',p_amount_toea,v_time,v_transfer,v_sender);
 return kina_private.cloud_wallet()||jsonb_build_object('transferReference','CLOUD-TRANSFER-'||v_transfer::text,'transferCreatedAt',v_time);
end $$;
revoke all on function kina_private.find_demo_recipient(uuid,uuid),kina_private.transfer_demo(uuid,uuid,uuid,bigint) from public,anon,authenticated;
grant execute on function kina_private.find_demo_recipient(uuid,uuid),kina_private.transfer_demo(uuid,uuid,uuid,bigint) to authenticated;

create function public.find_demo_recipient(p_expected_user uuid,p_recipient uuid) returns jsonb
 language sql security invoker set search_path='' as $$ select kina_private.find_demo_recipient(p_expected_user,p_recipient);$$;
create function public.transfer_demo_funds(p_expected_user uuid,p_request_id uuid,p_recipient uuid,p_amount_toea bigint) returns jsonb
 language sql security invoker set search_path='' as $$ select kina_private.transfer_demo(p_expected_user,p_request_id,p_recipient,p_amount_toea);$$;
revoke all on function public.find_demo_recipient(uuid,uuid),public.transfer_demo_funds(uuid,uuid,uuid,bigint) from public,anon,authenticated;
grant execute on function public.find_demo_recipient(uuid,uuid),public.transfer_demo_funds(uuid,uuid,uuid,bigint) to authenticated;
