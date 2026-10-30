
begin;
insert into auth.users(id,email,email_confirmed_at) values
('a0777777-7777-4777-8777-777777777777','peer-a@example.invalid',now()),
('b0888888-8888-4888-8888-888888888888','peer-b@example.invalid',now());
insert into public.sandbox_profiles(id,display_name) values
('a0777777-7777-4777-8777-777777777777','Sender fixture'),
('b0888888-8888-4888-8888-888888888888','Receiver fixture');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0777777-7777-4777-8777-777777777777","role":"authenticated"}',true);
select public.post_cloud_demo_transaction(auth.uid(),'a0000000-0000-4000-8000-000000000001','received','Test funding','Fixture',10000);
do $$ declare r jsonb;begin
 r:=public.find_demo_recipient(auth.uid(),'b0888888-8888-4888-8888-888888888888');
 if r->>'displayName'<>'Receiver fixture' or r ? 'email' then raise exception 'Invalid lookup disclosure';end if;
 r:=public.transfer_demo_funds(auth.uid(),'a0000000-0000-4000-8000-000000000002','b0888888-8888-4888-8888-888888888888',1000);
 if (r->>'balanceToea')::bigint<>9000 or r->>'transferReference' is null then raise exception 'Wrong sender result';end if;
 r:=public.transfer_demo_funds(auth.uid(),'a0000000-0000-4000-8000-000000000002','b0888888-8888-4888-8888-888888888888',1000);
 if (r->>'balanceToea')::bigint<>9000 or jsonb_array_length(r->'transactions')<>2 then raise exception 'Duplicate sender debit';end if;
 begin perform public.transfer_demo_funds(auth.uid(),'a0000000-0000-4000-8000-000000000002','b0888888-8888-4888-8888-888888888888',2000);
 raise exception 'Changed payload accepted';exception when invalid_parameter_value then null;end;
 begin perform public.transfer_demo_funds(auth.uid(),gen_random_uuid(),auth.uid(),1000);
 raise exception 'Self transfer accepted';exception when invalid_parameter_value then null;end;
 begin perform public.transfer_demo_funds(auth.uid(),gen_random_uuid(),'c0999999-9999-4999-8999-999999999999',1000);
 raise exception 'Unknown recipient accepted';exception when no_data_found then null;end;
 begin perform public.transfer_demo_funds(auth.uid(),gen_random_uuid(),'b0888888-8888-4888-8888-888888888888',9001);
 raise exception 'Overspend accepted' using errcode='XX000';exception when raise_exception then
 if sqlerrm<>'Insufficient demo balance' then raise;end if;end;
 begin perform public.post_cloud_demo_transaction(auth.uid(),gen_random_uuid(),'sent','Old debit','Fixture',-10);
 raise exception 'New debit-only send accepted';exception when invalid_parameter_value then null;end;
 begin perform public.transfer_demo_funds('b0888888-8888-4888-8888-888888888888',gen_random_uuid(),auth.uid(),1000);
 raise exception 'Wrong sender accepted';exception when invalid_authorization_specification then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"b0888888-8888-4888-8888-888888888888","role":"authenticated"}',true);
do $$ declare r jsonb;begin
 r:=public.cloud_demo_snapshot(auth.uid());
 if (r->>'balanceToea')::bigint<>1000 or jsonb_array_length(r->'transactions')<>1 then raise exception 'Receiver missing or doubled';end if;
 if (select count(*) from public.cloud_demo_transactions)<>1 then raise exception 'Other history leaked';end if;
end $$;
reset role;
do $$ begin
 if (select sum(balance_toea) from public.cloud_demo_wallets where user_id in('a0777777-7777-4777-8777-777777777777','b0888888-8888-4888-8888-888888888888'))<>10000
 then raise exception 'Funds not conserved';end if;
 if (select count(distinct transfer_id) from public.cloud_demo_transactions where user_id in('a0777777-7777-4777-8777-777777777777','b0888888-8888-4888-8888-888888888888') and transfer_id is not null)<>1
 then raise exception 'References do not match';end if;
end $$;
delete from auth.users where id='b0888888-8888-4888-8888-888888888888';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0777777-7777-4777-8777-777777777777","role":"authenticated"}',true);
do $$ declare r jsonb;begin
 r:=public.transfer_demo_funds(auth.uid(),'a0000000-0000-4000-8000-000000000002','b0888888-8888-4888-8888-888888888888',1000);
 if (r->>'balanceToea')::bigint<>9000 then raise exception 'Retry after deletion debited again';end if;
end $$;
reset role;
set local role anon;
do $$ begin
 begin perform public.find_demo_recipient(null,gen_random_uuid());raise exception 'Anonymous lookup accepted';
 exception when insufficient_privilege then null;end;
 begin perform public.transfer_demo_funds(null,gen_random_uuid(),gen_random_uuid(),1000);raise exception 'Anonymous transfer accepted';
 exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
