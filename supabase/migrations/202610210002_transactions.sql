create or replace function private.require_user() returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=auth.uid(); begin
 if u is null or not exists(select 1 from auth.users where id=u and email_confirmed_at is not null) then raise exception 'Verify your email and sign in first'; end if;
 return u;
end $$;
create or replace function private.person(p_name text,p_phone text,p_org text default '') returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=private.require_user(); p uuid; e text; begin
 if length(trim(p_name)) not between 2 and 120 or length(p_phone)>40 or length(p_org)>160 then raise exception 'Check your name and contact details'; end if;
 select email into e from auth.users where id=u;
 insert into people(user_id,full_name,email,phone,organization) values(u,trim(p_name),e,trim(p_phone),trim(p_org))
 on conflict(user_id) do update set full_name=excluded.full_name,email=excluded.email,phone=excluded.phone,organization=excluded.organization returning id into p;
 return p;
end $$;
create or replace function private.record_order(p_order uuid,p_type text,p_data jsonb default '{}') returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 insert into order_events(order_id,event_type,actor_user_id,metadata) values(p_order,p_type,auth.uid(),p_data);
 insert into audit_logs(event_id,actor_user_id,action,entity_id,metadata) select event_id,auth.uid(),p_type,id,p_data from orders where id=p_order;
end $$;
create or replace function private.notify(p_order uuid,p_type text,p_message text,p_key text) returns void language sql security definer set search_path=public,pg_temp as $$
 insert into notification_events(user_id,event_id,order_id,type,message,dedupe_key)
 select buyer_user_id,event_id,id,p_type,p_message,p_key from orders where id=p_order on conflict(dedupe_key) do nothing;
$$;

create or replace function public.save_cart(p_event uuid,p_items jsonb) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=private.require_user(); begin
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)>50 or octet_length(p_items::text)>20000 then raise exception 'Invalid cart'; end if;
 insert into carts(user_id,event_id,items) values(u,p_event,p_items) on conflict(user_id,event_id) do update set items=excluded.items,updated_at=now();
end $$;
create or replace function public.create_order(p_event uuid,p_items jsonb,p_name text,p_phone text,p_idempotency uuid)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=private.require_user(); person uuid; o uuid; existing orders%rowtype; cfg commerce_settings%rowtype; r record; v record; total bigint:=0; item uuid; deadline timestamptz; h text;
begin
 if p_idempotency is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items) not between 1 and 30 then raise exception 'Add items to your cart'; end if;
 h:=md5(jsonb_build_object('event',p_event,'items',p_items,'name',p_name,'phone',p_phone)::text);
 perform pg_advisory_xact_lock(hashtextextended(u::text||p_idempotency::text,0));
 select * into existing from orders where buyer_user_id=u and idempotency_key=p_idempotency;
 if found then if existing.request_hash<>h then raise exception 'Checkout request changed. Try again'; end if; return existing.id; end if;
 select * into cfg from commerce_settings where event_id=p_event;
 if not found or not cfg.orders_open or not exists(select 1 from events where id=p_event and status='published') then raise exception 'Orders are not open yet'; end if;
 if coalesce(cfg.bank_details->>'account_number','')='' or coalesce(cfg.bank_details->>'bank_name','')='' then raise exception 'Payment instructions are not configured'; end if;
 if (select count(*) from orders where buyer_user_id=u and status in ('awaiting_payment','payment_review'))>=3 then raise exception 'Complete your existing unpaid orders first'; end if;
 person:=private.person(p_name,p_phone); deadline:=now()+make_interval(hours=>cfg.payment_window_hours);
 if exists(select 1 from jsonb_to_recordset(p_items) as x(variant_id uuid,quantity integer) where variant_id is null or quantity is null or quantity<=0 or quantity>100) then raise exception 'Invalid quantity'; end if;
 -- Lock variants and inventory in the same order for all concurrent checkouts.
 for r in select variant_id,sum(quantity)::integer as quantity from jsonb_to_recordset(p_items) as x(variant_id uuid,quantity integer) group by variant_id order by variant_id loop
 select pv.*,p.name,p.status,p.event_id,ib.on_hand,ib.reserved into v from product_variants pv join products p on p.id=pv.product_id join inventory_balances ib on ib.variant_id=pv.id where pv.id=r.variant_id for update of pv,ib;
 if not found or v.event_id<>p_event or v.status<>'active' or not v.active or v.price_minor is null or r.quantity>v.max_per_order then raise exception 'A selected product is not available'; end if;
 if v.on_hand-v.reserved<r.quantity then raise exception 'Not enough stock for % (%)',v.name,v.label; end if;
 total:=total+v.price_minor*r.quantity;
 end loop;
 insert into orders(event_id,buyer_user_id,buyer_person_id,total_minor,buyer_snapshot,bank_details_snapshot,payment_due_at,idempotency_key,request_hash)
 values(p_event,u,person,total,jsonb_build_object('name',p_name,'phone',p_phone,'email',(select email from people where id=person)),cfg.bank_details,deadline,p_idempotency,h) returning id into o;
 for r in select variant_id,sum(quantity)::integer as quantity from jsonb_to_recordset(p_items) as x(variant_id uuid,quantity integer) group by variant_id order by variant_id loop
 select pv.*,p.name into v from product_variants pv join products p on p.id=pv.product_id where pv.id=r.variant_id;
 insert into order_items(order_id,variant_id,name_snapshot,variant_snapshot,sku_snapshot,quantity,unit_price_minor) values(o,v.id,v.name,v.label,v.sku,r.quantity,v.price_minor) returning id into item;
 update inventory_balances set reserved=reserved+r.quantity where variant_id=v.id;
 insert into inventory_movements(variant_id,order_item_id,on_hand_delta,reserved_delta,reason,actor_user_id) values(v.id,item,0,r.quantity,'checkout reservation',u);
 insert into stock_reservations(order_item_id,expires_at) values(item,deadline);
 end loop;
 insert into payments(order_id,amount_minor) values(o,total);
 update carts set items='[]',updated_at=now() where user_id=u and event_id=p_event;
 perform private.record_order(o,'order_placed');
 perform private.notify(o,'order_placed','Order received. Transfer the exact amount and upload your receipt.','placed:'||o);
 return o;
end $$;

create or replace function public.submit_receipt(p_payment uuid,p_path text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=private.require_user(); o orders%rowtype; p payments%rowtype; deadline timestamptz; begin
 select ord.* into o from orders ord join payments pay on pay.order_id=ord.id where pay.id=p_payment for update of ord;
 if not found or o.buyer_user_id<>u then raise exception 'Order not found'; end if;
 select * into p from payments where id=p_payment for update;
 if o.status not in ('awaiting_payment','payment_review') or o.payment_due_at<now() then raise exception 'Payment window has closed. Contact the committee'; end if;
 if p.status='submitted' and exists(select 1 from payment_receipts where payment_id=p_payment and storage_path=p_path) then return; end if;
 if p.status<>'pending' then raise exception 'This payment has already been submitted'; end if;
 if split_part(p_path,'/',1)<>u::text or split_part(p_path,'/',2)<>p_payment::text or not exists(select 1 from storage.objects where bucket_id='payment-receipts' and name=p_path) then raise exception 'Upload your receipt before submitting'; end if;
 insert into payment_receipts(payment_id,uploaded_by,storage_path) values(p_payment,u,p_path);
 select now()+make_interval(hours=>review_window_hours) into deadline from commerce_settings where event_id=o.event_id;
 update payments set status='submitted' where id=p_payment;
 update orders set status='payment_review',payment_due_at=deadline where id=o.id;
 update stock_reservations set expires_at=deadline where order_item_id in(select id from order_items where order_id=o.id) and status='held';
 perform private.record_order(o.id,'receipt_submitted');
 perform private.notify(o.id,'receipt_received','Receipt received. Finance will review your bank transfer.','receipt:'||p_payment);
end $$;

create or replace function public.review_payment(p_payment uuid,p_approve boolean,p_note text,p_bank_reference text default '') returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=private.require_user(); o orders%rowtype; p payments%rowtype; r record; f uuid; deadline timestamptz; begin
 select ord.* into o from orders ord join payments pay on pay.order_id=ord.id where pay.id=p_payment for update of ord;
 if not found or not private.has_role(o.event_id,array['finance']) then raise exception 'Finance access required'; end if;
 select * into p from payments where id=p_payment for update;
 if p.status='approved' and p_approve then return; end if;
 if p.status<>'submitted' or o.status<>'payment_review' then raise exception 'Payment is not awaiting review'; end if;
 if length(trim(p_note))<3 then raise exception 'Enter a review note'; end if;
 if p_approve then
 if length(trim(p_bank_reference))<3 or p.amount_minor<>o.total_minor then raise exception 'Verify the exact bank credit and reference'; end if;
 if exists(select 1 from order_items i left join stock_reservations s on s.order_item_id=i.id where i.order_id=o.id and (s.status is distinct from 'held')) then raise exception 'Reservation unavailable. Resolve stock before approval'; end if;
 for r in select i.* from order_items i where order_id=o.id order by variant_id nulls last,ticket_type_id loop
 if r.variant_id is not null then
 update inventory_balances set on_hand=on_hand-r.quantity,reserved=reserved-r.quantity where variant_id=r.variant_id;
 insert into inventory_movements(variant_id,order_item_id,on_hand_delta,reserved_delta,reason,actor_user_id) values(r.variant_id,r.id,-r.quantity,-r.quantity,'payment approved',u);
 else update ticket_types set reserved=reserved-r.quantity,allocated=allocated+r.quantity where id=r.ticket_type_id; end if;
 end loop;
 update stock_reservations set status='committed' where order_item_id in(select id from order_items where order_id=o.id);
 update payments set status='approved',bank_reference=trim(p_bank_reference),review_note=p_note,reviewed_by=u,reviewed_at=now() where id=p_payment;
 update orders set status='confirmed',confirmed_at=now() where id=o.id;
 if exists(select 1 from order_items where order_id=o.id and variant_id is not null) then
 insert into fulfillments(order_id) values(o.id) returning id into f;
 insert into fulfillment_items(fulfillment_id,order_item_id,quantity) select f,id,quantity from order_items where order_id=o.id and variant_id is not null;
 end if;
 update registrations set status='submitted' where order_item_id in(select id from order_items where order_id=o.id) and status='awaiting_payment';
 perform private.record_order(o.id,'payment_approved',jsonb_build_object('payment_id',p_payment,'reference',p_bank_reference));
 perform private.notify(o.id,'payment_approved','Your payment is approved. Your order is confirmed.','approved:'||o.id);
 else
 update payments set status='rejected',review_note=p_note,reviewed_by=u,reviewed_at=now() where id=p_payment;
 select now()+make_interval(hours=>payment_window_hours) into deadline from commerce_settings where event_id=o.event_id;
 update orders set status='awaiting_payment',payment_due_at=deadline where id=o.id;
 update stock_reservations set expires_at=deadline where order_item_id in(select id from order_items where order_id=o.id) and status='held';
 insert into payments(order_id,amount_minor) values(o.id,o.total_minor);
 perform private.record_order(o.id,'payment_rejected',jsonb_build_object('reason',p_note));
 perform private.notify(o.id,'payment_rejected','Receipt rejected: '||p_note,'rejected:'||p_payment);
 end if;
end $$;

create or replace function private.release_order(p_order uuid,p_status text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare o orders%rowtype; r record; begin
 select * into o from orders where id=p_order for update;
 if o.status not in ('awaiting_payment','payment_review') then return; end if;
 for r in select i.* from order_items i join stock_reservations s on s.order_item_id=i.id where i.order_id=o.id and s.status='held' order by i.variant_id nulls last,i.ticket_type_id loop
 if r.variant_id is not null then
 update inventory_balances set reserved=reserved-r.quantity where variant_id=r.variant_id;
 insert into inventory_movements(variant_id,order_item_id,on_hand_delta,reserved_delta,reason,actor_user_id) values(r.variant_id,r.id,0,-r.quantity,p_status,auth.uid());
 else update ticket_types set reserved=reserved-r.quantity where id=r.ticket_type_id; end if;
 end loop;
 update stock_reservations set status='released' where status='held' and order_item_id in(select id from order_items where order_id=o.id);
 update orders set status=p_status where id=o.id;
 update payments set status='expired' where order_id=o.id and status in ('pending','submitted');
 update registrations set status='cancelled' where order_item_id in(select id from order_items where order_id=o.id);
 perform private.record_order(o.id,'order_'||p_status);
 perform private.notify(o.id,'order_'||p_status,'Order '||p_status||'. Contact the committee if you already transferred money.',p_status||':'||o.id);
end $$;
create or replace function public.cancel_order(p_order uuid) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare o orders%rowtype; begin
 perform private.require_user(); select * into o from orders where id=p_order for update;
 if not found or not (private.has_role(o.event_id,array['finance']) or (o.buyer_user_id=auth.uid() and o.status='awaiting_payment')) then raise exception 'Cannot cancel this order'; end if;
 if o.status not in ('awaiting_payment','payment_review') then raise exception 'Confirmed payments require the refund process'; end if;
 perform private.release_order(p_order,'cancelled');
end $$;
create or replace function public.expire_unpaid_orders(p_event uuid) returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare r record; n integer:=0; begin
 if auth.role()<>'service_role' and not private.has_role(p_event,array['finance','shop_manager']) then raise exception 'Staff access required'; end if;
 for r in select id from orders where event_id=p_event and status in ('awaiting_payment','payment_review') and payment_due_at<now() order by id for update skip locked loop
 perform private.release_order(r.id,'expired'); n:=n+1; end loop; return n;
end $$;
create or replace function public.record_collection(p_fulfillment uuid,p_quantities jsonb,p_ready boolean default false) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare f fulfillments%rowtype; o orders%rowtype; r record; current_item fulfillment_items%rowtype; begin
 perform private.require_user();
 select ord.* into o from orders ord join fulfillments ff on ff.order_id=ord.id where ff.id=p_fulfillment for update of ord;
 if not found or not private.has_role(o.event_id,array['shop_manager']) then raise exception 'Shop access required'; end if;
 select * into f from fulfillments where id=p_fulfillment for update;
 if o.status<>'confirmed' then raise exception 'Order is not confirmed'; end if;
 if exists(select 1 from refunds r join payments p on p.id=r.payment_id where p.order_id=o.id) then raise exception 'Refund recorded. Finance must resolve pickup manually'; end if;
 if p_ready and f.status='pending' then
 update fulfillments set status='ready' where id=f.id; perform private.record_order(o.id,'ready_for_collection');
 perform private.notify(o.id,'ready_for_collection','Your merchandise is ready for collection.','ready:'||o.id); return;
 end if;
 if f.status not in ('ready','partially_collected','collected') then raise exception 'Mark the order ready first'; end if;
 if jsonb_typeof(p_quantities)<>'array' or jsonb_array_length(p_quantities)=0 then raise exception 'Select items to collect'; end if;
 for r in select * from jsonb_to_recordset(p_quantities) as x(id uuid,collected_quantity integer) loop
 select * into current_item from fulfillment_items where id=r.id and fulfillment_id=f.id for update;
 if not found or r.collected_quantity is null or r.collected_quantity<current_item.collected_quantity or r.collected_quantity>current_item.quantity then raise exception 'Invalid collection quantity'; end if;
 update fulfillment_items set collected_quantity=r.collected_quantity where id=r.id;
 end loop;
 update fulfillments set status=case when not exists(select 1 from fulfillment_items where fulfillment_id=f.id and collected_quantity<quantity) then 'collected' else 'partially_collected' end where id=f.id;
 perform private.record_order(o.id,'collection_recorded',p_quantities);
end $$;
create or replace function public.record_refund(p_payment uuid,p_amount bigint,p_reference text,p_reason text,p_idempotency uuid) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare p payments%rowtype; o orders%rowtype; refund_id uuid; previous refunds%rowtype; begin
 perform private.require_user(); select ord.* into o from orders ord join payments pay on pay.order_id=ord.id where pay.id=p_payment for update of ord;
 if not found or not private.has_role(o.event_id,array['finance']) then raise exception 'Finance access required'; end if;
 select * into p from payments where id=p_payment for update;
 select * into previous from refunds where idempotency_key=p_idempotency;
 if found then if previous.payment_id<>p_payment or previous.amount_minor<>p_amount then raise exception 'Refund key already used'; end if; return previous.id; end if;
 if p.status<>'approved' or p_amount<=0 or p_amount is null or length(trim(p_reference))<3 or length(trim(p_reason))<3 or p_idempotency is null then raise exception 'Enter the completed refund amount, bank reference and reason'; end if;
 if coalesce((select sum(amount_minor) from refunds where payment_id=p.id),0)+p_amount>p.amount_minor then raise exception 'Refund exceeds the approved payment'; end if;
 insert into refunds(payment_id,amount_minor,bank_reference,reason,processed_by,idempotency_key) values(p.id,p_amount,p_reference,p_reason,auth.uid(),p_idempotency) returning id into refund_id;
 perform private.record_order(o.id,'refund_recorded',jsonb_build_object('amount_minor',p_amount,'reference',p_reference));
 perform private.notify(o.id,'refund_recorded','A refund has been recorded. Check your order for details.','refund:'||refund_id);
 return refund_id;
end $$;
