
begin;
insert into auth.users(id,email,email_confirmed_at) values
 ('aa111111-1111-4111-8111-111111111111','cloud-a@example.invalid',now()),
 ('bb222222-2222-4222-8222-222222222222','cloud-b@example.invalid',now()),
 ('cc333333-3333-4333-8333-333333333333','cloud-unconfirmed@example.invalid',null);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"aa111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
do $$
declare r jsonb;
begin
 r := public.cloud_demo_snapshot(auth.uid());
 if (r->>'balanceToea')::bigint <> 0 then raise exception 'Nonzero initial balance'; end if;
 r := public.post_cloud_demo_transaction(auth.uid(),'11111111-1111-4111-8111-111111111111','received','Demo deposit','Test',10000);
 r := public.post_cloud_demo_transaction(auth.uid(),'11111111-1111-4111-8111-111111111111','received','Demo deposit','Test',10000);
 if (r->>'balanceToea')::bigint <> 10000 or jsonb_array_length(r->'transactions') <> 1 then raise exception 'Duplicate committed'; end if;
 begin
  perform public.post_cloud_demo_transaction(auth.uid(),'11111111-1111-4111-8111-111111111111','received','Demo deposit','Test',20000);
  raise exception 'Changed payload accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.post_cloud_demo_transaction(auth.uid(),'22222222-2222-4222-8222-222222222222','received','Invalid','Test',-100);
  raise exception 'Wrong sign accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.post_cloud_demo_transaction(auth.uid(),'22222222-2222-4222-8222-222222222222','electricity','Too much','Test',-10001);
  raise exception 'Overspend accepted' using errcode='XX000';
 exception when raise_exception then
  if sqlerrm <> 'Insufficient demo balance' then raise; end if;
 end;
 r := public.post_cloud_demo_transaction(auth.uid(),'22222222-2222-4222-8222-222222222222','electricity','Demo bill','Test',-4000);
 if (r->>'balanceToea')::bigint <> 6000 then raise exception 'Wrong balance'; end if;
 begin
  update public.cloud_demo_wallets set balance_toea=999999;
  raise exception 'Direct update accepted';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.cloud_demo_transactions(user_id,request_id,kind,title,detail,amount_toea)
   values('aa111111-1111-4111-8111-111111111111',gen_random_uuid(),'received','Forgery','Test',10);
  raise exception 'Direct ledger insert accepted';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims','{"sub":"bb222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
do $$ declare r jsonb; begin
 begin
 perform public.post_cloud_demo_transaction('aa111111-1111-4111-8111-111111111111','ffffffff-ffff-4fff-8fff-ffffffffffff','received','Wrong account','Test',1000);
 raise exception 'Wrong account mutation accepted';
 exception when invalid_authorization_specification then null; end;
 if (select count(*) from public.cloud_demo_transactions) <> 0 then raise exception 'History leaked'; end if;
 if (select count(*) from public.cloud_demo_wallets) <> 0 then raise exception 'Balance leaked'; end if;
 r := public.cloud_demo_snapshot(auth.uid());
 if (r->>'balanceToea')::bigint <> 0 then raise exception 'Account B inherited money'; end if;
end $$;
select set_config('request.jwt.claims','{"sub":"cc333333-3333-4333-8333-333333333333","role":"authenticated"}',true);
do $$ begin
 begin perform public.cloud_demo_snapshot(auth.uid()); raise exception 'Unconfirmed user accepted';
 exception when invalid_authorization_specification then null; end;
end $$;
reset role;
set local role anon;
do $$ begin
 begin perform public.cloud_demo_snapshot(auth.uid()); raise exception 'Anonymous RPC allowed';
 exception when insufficient_privilege then null; end;
 begin perform 1 from public.cloud_demo_transactions; raise exception 'Anonymous read allowed';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
