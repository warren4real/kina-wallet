
begin;
insert into auth.users(id,email,email_confirmed_at) values
('a0777777-7777-4777-8777-777777777777','recovery-a@example.invalid',now()),
('b0888888-8888-4888-8888-888888888888','recovery-b@example.invalid',now());
insert into public.sandbox_profiles(id,display_name) values
('a0777777-7777-4777-8777-777777777777','Recovery A'),
('b0888888-8888-4888-8888-888888888888','Recovery B');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0777777-7777-4777-8777-777777777777","role":"authenticated"}',true);
do $$ declare r jsonb; original jsonb; receipt jsonb; begin
 if public.cloud_demo_request_status(auth.uid(),'a0000000-0000-4000-8000-000000000002') is not null then raise exception 'Unknown request marked complete';end if;
 perform public.post_cloud_demo_transaction(auth.uid(),'a0000000-0000-4000-8000-000000000001','received','Funding','Fixture',10000);
 r:=public.cloud_demo_request_status(auth.uid(),'a0000000-0000-4000-8000-000000000001');
 if r->>'reference'<>'CLOUD-DEMO-a0000000-0000-4000-8000-000000000001' then raise exception 'Generic receipt wrong';end if;
 original:=public.transfer_demo_funds(auth.uid(),'a0000000-0000-4000-8000-000000000002','b0888888-8888-4888-8888-888888888888',1000);
 receipt:=public.cloud_demo_request_status(auth.uid(),'a0000000-0000-4000-8000-000000000002');
 if receipt->>'reference' is distinct from original->>'transferReference' or receipt->>'createdAt' is distinct from original->>'transferCreatedAt' then raise exception 'Recovered receipt wrong';end if;
 perform public.cloud_demo_request_status(auth.uid(),'a0000000-0000-4000-8000-000000000002');
 r:=public.cloud_demo_snapshot(auth.uid());
 if (r->>'balanceToea')::int<>9000 or jsonb_array_length(r->'transactions')<>2 then raise exception 'Status check changed funds';end if;
 begin
 perform public.cloud_demo_request_status('b0888888-8888-4888-8888-888888888888','a0000000-0000-4000-8000-000000000002');
 raise exception 'Wrong owner accepted';exception when invalid_authorization_specification then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"b0888888-8888-4888-8888-888888888888","role":"authenticated"}',true);
do $$ begin
 if public.cloud_demo_request_status(auth.uid(),'a0000000-0000-4000-8000-000000000002') is not null then raise exception 'Other account request exposed';end if;
end $$;
reset role;set local role anon;
do $$ begin
 begin perform public.cloud_demo_request_status('a0777777-7777-4777-8777-777777777777','a0000000-0000-4000-8000-000000000002');raise exception 'Anonymous accepted';exception when insufficient_privilege then null;end;
end $$;
rollback;
select 'read-only recovery, matching receipt, missing request, owner isolation and anonymous denial passed; fixtures rolled back' result;
