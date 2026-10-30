
begin;
insert into auth.users(id,email,email_confirmed_at) values
('ee111111-1111-4111-8111-111111111111','recipient-test-a@example.invalid',now()),
('ee222222-2222-4222-8222-222222222222','recipient-test-b@example.invalid',now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"ee111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
insert into public.cloud_demo_recipients(user_id,phone_number,name) values
('ee111111-1111-4111-8111-111111111111','72222222','Private A');
insert into public.sandbox_profiles(id,display_name,phone_number) values
('ee111111-1111-4111-8111-111111111111','A','72222222');
update public.cloud_demo_recipients set name='Updated A',phone_number='73333333' where phone_number='72222222';
do $$ begin
 begin
 insert into public.cloud_demo_recipients(user_id,phone_number,name) values('ee222222-2222-4222-8222-222222222222','74444444','Wrong owner');
 raise exception 'Cross-owner insert accepted';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims','{"sub":"ee222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
do $$ declare n bigint; begin
 if (select count(*) from public.cloud_demo_recipients)<>0 then raise exception 'Recipient leaked';end if;
 update public.cloud_demo_recipients set name='Hijack' where phone_number='73333333';
 get diagnostics n=row_count;if n<>0 then raise exception 'Cross-account update accepted';end if;
 delete from public.cloud_demo_recipients where phone_number='73333333';
 get diagnostics n=row_count;if n<>0 then raise exception 'Cross-account delete accepted';end if;
end $$;
reset role;
delete from auth.users where id='ee111111-1111-4111-8111-111111111111';
do $$ begin
 if exists(select 1 from public.cloud_demo_recipients where user_id='ee111111-1111-4111-8111-111111111111')
 or exists(select 1 from public.sandbox_profiles where id='ee111111-1111-4111-8111-111111111111') then raise exception 'Deletion did not cascade';end if;
end $$;
set local role anon;
do $$ begin
 begin perform 1 from public.cloud_demo_recipients;raise exception 'Anonymous read permitted';
 exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
