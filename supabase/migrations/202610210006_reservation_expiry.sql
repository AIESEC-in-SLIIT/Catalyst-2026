-- Called by the Supabase Cron job in supabase/cron.sql. No browser role can
-- execute this function. It releases stock and ticket seats in one transaction.
create or replace function private.expire_all_orders()
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare current_order record; expired_count integer := 0;
begin
 for current_order in
  select id from orders
  where status in ('awaiting_payment','payment_review') and payment_due_at < now()
  order by id for update skip locked
 loop
  perform private.release_order(current_order.id,'expired');
  expired_count := expired_count + 1;
 end loop;
 return expired_count;
end $$;
revoke all on function private.expire_all_orders() from public,anon,authenticated,service_role;
