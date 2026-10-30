
create function public.cloud_demo_request_status(p_expected_user uuid,p_request_id uuid) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare result jsonb;
begin
 if auth.uid() is null or auth.uid() is distinct from p_expected_user then
  raise exception 'Account changed' using errcode='28000';
 end if;
 select jsonb_build_object('reference',
   case when t.transfer_id is null then 'CLOUD-DEMO-'||t.request_id::text else 'CLOUD-TRANSFER-'||t.transfer_id::text end,
   'createdAt',t.created_at)
 into result from public.cloud_demo_transactions t
 where t.user_id=p_expected_user and t.request_id=p_request_id;
 return result;
end; $$;
revoke all on function public.cloud_demo_request_status(uuid,uuid) from public,anon,authenticated;
grant execute on function public.cloud_demo_request_status(uuid,uuid) to authenticated;
