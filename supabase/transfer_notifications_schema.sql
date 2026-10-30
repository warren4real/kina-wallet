
create table public.demo_transfer_reads (
 user_id uuid not null,
 request_id uuid not null,
 read_at timestamptz not null default now(),
 primary key (user_id, request_id),
 foreign key (user_id,request_id) references public.cloud_demo_transactions(user_id,request_id) on delete cascade
);
alter table public.demo_transfer_reads enable row level security;
revoke all on public.demo_transfer_reads from public, anon, authenticated;
grant select, insert(user_id,request_id) on public.demo_transfer_reads to authenticated;
create policy own_transfer_reads on public.demo_transfer_reads for select to authenticated
using ((select auth.uid()) = user_id);
create policy mark_own_transfer_read on public.demo_transfer_reads for insert to authenticated
with check ((select auth.uid()) = user_id and exists (
 select 1 from public.cloud_demo_transactions t
 where t.user_id = demo_transfer_reads.user_id and t.request_id = demo_transfer_reads.request_id and t.transfer_id is not null
));

create function public.demo_transfer_notifications(p_expected_user uuid) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare result jsonb;
begin
 if auth.uid() is null or auth.uid() is distinct from p_expected_user then
  raise exception 'Account changed' using errcode='28000';
 end if;
 select jsonb_build_object(
  'unreadCount', (select count(*) from public.cloud_demo_transactions t where t.user_id=p_expected_user and t.transfer_id is not null
    and not exists(select 1 from public.demo_transfer_reads r where r.user_id=t.user_id and r.request_id=t.request_id)),
  'items', coalesce((select jsonb_agg(n.item order by n.sequence desc) from (
    select t.sequence,jsonb_build_object('id',t.request_id,'title',t.title,'amountToea',t.amount_toea,'createdAt',t.created_at,
     'reference','CLOUD-TRANSFER-'||t.transfer_id::text,
     'isRead',exists(select 1 from public.demo_transfer_reads r where r.user_id=t.user_id and r.request_id=t.request_id)) item
    from public.cloud_demo_transactions t where t.user_id=p_expected_user and t.transfer_id is not null
    order by t.sequence desc limit 100
  ) n),'[]'::jsonb)
 ) into result;
 return result;
end; $$;
revoke all on function public.demo_transfer_notifications(uuid) from public,anon,authenticated;
grant execute on function public.demo_transfer_notifications(uuid) to authenticated;

create function public.read_demo_transfer_notification(p_expected_user uuid,p_request_id uuid) returns void
language plpgsql security invoker set search_path = '' as $$
begin
 if auth.uid() is null or auth.uid() is distinct from p_expected_user then
  raise exception 'Account changed' using errcode='28000';
 end if;
 insert into public.demo_transfer_reads(user_id,request_id) values(p_expected_user,p_request_id) on conflict do nothing;
end; $$;
revoke all on function public.read_demo_transfer_notification(uuid,uuid) from public,anon,authenticated;
grant execute on function public.read_demo_transfer_notification(uuid,uuid) to authenticated;
