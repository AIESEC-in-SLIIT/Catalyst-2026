-- Event scoped totals for the control room. The browser never calculates
-- financial metrics from a truncated page of orders.
create or replace function public.admin_dashboard(p_event uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare result jsonb; can_shop boolean;
begin
 if auth.uid() is null or not private.has_role(p_event,array['owner','finance','shop_manager','registration_manager']) then
  raise exception 'Admin access required';
 end if;
 can_shop := private.has_role(p_event,array['owner','finance','shop_manager']);
 select jsonb_build_object(
  'confirmed_value_minor',case when can_shop then coalesce((select sum(total_minor) from orders where event_id=p_event and status='confirmed'),0) else 0 end,
  'refunded_minor',case when can_shop then coalesce((select sum(r.amount_minor) from refunds r join payments p on p.id=r.payment_id join orders o on o.id=p.order_id where o.event_id=p_event),0) else 0 end,
  'awaiting_payment', case when can_shop then (select count(*) from orders where event_id=p_event and status='awaiting_payment') else 0 end,
  'receipts_to_review', case when can_shop then (select count(*) from payments p join orders o on o.id=p.order_id where o.event_id=p_event and p.status='submitted') else 0 end,
  'registrations', (select count(*) from registrations where event_id=p_event),
  'delegates', (select count(*) from delegates d join registrations r on r.id=d.registration_id where r.event_id=p_event and r.status='confirmed'),
  'ready_for_collection', case when can_shop then (select count(*) from fulfillments f join orders o on o.id=f.order_id where o.event_id=p_event and f.status='ready') else 0 end,
  'available_units', case when can_shop then coalesce((select sum(b.on_hand-b.reserved) from inventory_balances b join product_variants v on v.id=b.variant_id join products p on p.id=v.product_id where p.event_id=p_event),0) else 0 end
 ) into result;
 return result;
end $$;
revoke all on function public.admin_dashboard(uuid) from public,anon;
grant execute on function public.admin_dashboard(uuid) to authenticated;
