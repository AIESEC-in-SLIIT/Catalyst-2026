-- Configuration is role-checked and whitelisted; no browser table mutations.
create or replace function public.admin_save(p_event uuid,p_entity text,p_data jsonb) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare key uuid:=coalesce(nullif(p_data->>'id','')::uuid,gen_random_uuid()); role_needed text; old_stock integer; stock integer; form_version integer; begin
 perform private.require_user();
 role_needed:=case when p_entity in ('product','variant','stock') then 'shop_manager' when p_entity in ('ticket','form','delegation') then 'registration_manager' else 'owner' end;
 if not private.has_role(p_event,array[role_needed]) then raise exception 'You do not have permission for this change'; end if;
 case p_entity
 when 'event' then
 update events set name=p_data->>'name',status=p_data->>'status',venue=coalesce(p_data->>'venue',''),starts_at=nullif(p_data->>'starts_at','')::timestamptz where id=p_event; key:=p_event;
 when 'settings' then
 if coalesce((p_data->>'orders_open')::boolean,false) and (coalesce(p_data->'bank_details'->>'account_number','')='' or coalesce(p_data->'bank_details'->>'bank_name','')='') then raise exception 'Enter bank details before opening orders'; end if;
 insert into commerce_settings(event_id,orders_open,bank_details,pickup_instructions,support_email,payment_window_hours,review_window_hours)
 values(p_event,(p_data->>'orders_open')::boolean,p_data->'bank_details',p_data->>'pickup_instructions',p_data->>'support_email',(p_data->>'payment_window_hours')::integer,(p_data->>'review_window_hours')::integer)
 on conflict(event_id) do update set orders_open=excluded.orders_open,bank_details=excluded.bank_details,pickup_instructions=excluded.pickup_instructions,support_email=excluded.support_email,payment_window_hours=excluded.payment_window_hours,review_window_hours=excluded.review_window_hours; key:=p_event;
 when 'product' then
 if exists(select 1 from products where id=key and event_id<>p_event) then raise exception 'Event mismatch'; end if;
 if nullif(p_data->>'image_path','') is not null and p_data->>'image_path' !~ '^https://' then raise exception 'Image URL must use HTTPS'; end if;
 insert into products(id,event_id,slug,name,description,status,sort_order,image_path) values(key,p_event,p_data->>'slug',p_data->>'name',coalesce(p_data->>'description',''),p_data->>'status',coalesce((p_data->>'sort_order')::integer,0),nullif(p_data->>'image_path',''))
 on conflict(id) do update set slug=excluded.slug,name=excluded.name,description=excluded.description,status=excluded.status,sort_order=excluded.sort_order,image_path=excluded.image_path;
 when 'variant' then
 if not exists(select 1 from products where id=(p_data->>'product_id')::uuid and event_id=p_event) or exists(select 1 from product_variants where id=key and product_id<>(p_data->>'product_id')::uuid) then raise exception 'Product mismatch'; end if;
 if (p_data->>'active')::boolean and nullif(p_data->>'price_minor','') is null then raise exception 'Set a price before enabling the variant'; end if;
 insert into product_variants(id,product_id,sku,label,price_minor,active,max_per_order) values(key,(p_data->>'product_id')::uuid,p_data->>'sku',p_data->>'label',nullif(p_data->>'price_minor','')::bigint,(p_data->>'active')::boolean,coalesce((p_data->>'max_per_order')::integer,5))
 on conflict(id) do update set sku=excluded.sku,label=excluded.label,price_minor=excluded.price_minor,active=excluded.active,max_per_order=excluded.max_per_order;
 insert into inventory_balances(variant_id) values(key) on conflict do nothing;
 when 'stock' then
 key:=(p_data->>'variant_id')::uuid;
 if not exists(select 1 from product_variants v join products p on p.id=v.product_id where v.id=key and p.event_id=p_event) then raise exception 'Variant mismatch'; end if;
 if length(trim(p_data->>'reason'))<3 then raise exception 'Explain the stock adjustment'; end if;
 select on_hand into old_stock from inventory_balances where variant_id=key for update;
 stock:=(p_data->>'on_hand')::integer;
 update inventory_balances set on_hand=stock where variant_id=key;
 insert into inventory_movements(variant_id,on_hand_delta,reserved_delta,reason,actor_user_id) values(key,stock-old_stock,0,p_data->>'reason',auth.uid());
 when 'ticket' then
 if exists(select 1 from ticket_types where id=key and event_id<>p_event) then raise exception 'Event mismatch'; end if;
 insert into ticket_types(id,event_id,name,price_minor,capacity,active) values(key,p_event,p_data->>'name',(p_data->>'price_minor')::bigint,(p_data->>'capacity')::integer,(p_data->>'active')::boolean)
 on conflict(id) do update set name=excluded.name,price_minor=excluded.price_minor,capacity=excluded.capacity,active=excluded.active;
 when 'form' then
 -- Publishing always creates a version. Existing answers retain their original schema.
 if jsonb_typeof(p_data->'fields')<>'array' or jsonb_array_length(p_data->'fields')>30 then raise exception 'Invalid form fields'; end if;
 if exists(select 1 from jsonb_array_elements(p_data->'fields') f where coalesce(f->>'key','') !~ '^[a-z][a-z0-9_]{0,39}$' or coalesce(f->>'type','') not in ('text','textarea','select') or coalesce(f->>'label','')='') then raise exception 'Each field needs a key, label and supported type'; end if;
 if (select count(*) from jsonb_array_elements(p_data->'fields'))<>(select count(distinct f->>'key') from jsonb_array_elements(p_data->'fields') f) then raise exception 'Field keys must be unique'; end if;
 perform 1 from events where id=p_event for update;
 select coalesce(max(version),0)+1 into form_version from registration_forms where event_id=p_event;
 update registration_forms set active=false where event_id=p_event;
 insert into registration_forms(event_id,version,fields,active) values(p_event,form_version,p_data->'fields',true) returning id into key;
 when 'delegation' then
 if exists(select 1 from delegations where id=key and event_id<>p_event) then raise exception 'Event mismatch'; end if;
 insert into delegations(id,event_id,name,organization) values(key,p_event,p_data->>'name',coalesce(p_data->>'organization','')) on conflict(id) do update set name=excluded.name,organization=excluded.organization;
 when 'staff' then
 if p_data->>'role' not in ('finance','shop_manager','registration_manager','checkin_staff') then raise exception 'Owners are managed through the secure database bootstrap'; end if;
 if nullif(p_data->>'user_id','') is not null then key:=(p_data->>'user_id')::uuid;
 if not exists(select 1 from staff_memberships where user_id=key and event_id=p_event and role=p_data->>'role') then raise exception 'Staff role not found for this event'; end if;
 else select id into key from auth.users where lower(email)=lower(trim(p_data->>'email')) and email_confirmed_at is not null;
 if key is null then raise exception 'This staff member must sign in and verify their email first'; end if; end if;
 insert into staff_memberships(user_id,event_id,role,active) values(key,p_event,p_data->>'role',coalesce((p_data->>'active')::boolean,true)) on conflict(user_id,event_id,role) where event_id is not null do update set active=excluded.active;
 else raise exception 'Unsupported admin operation';
 end case;
 insert into audit_logs(event_id,actor_user_id,action,entity_id,metadata) values(p_event,auth.uid(),'save_'||p_entity,key,jsonb_build_object('entity',p_entity));
 return key;
end $$;

create or replace function public.submit_registration(p_event uuid,p_ticket uuid,p_name text,p_phone text,p_org text,p_answers jsonb,p_idempotency uuid) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare u uuid:=private.require_user(); person uuid; t ticket_types%rowtype; form registration_forms%rowtype; cfg commerce_settings%rowtype; field jsonb; reg uuid; o uuid; item uuid; deadline timestamptz; existing orders%rowtype; h text; begin
 if not exists(select 1 from events where id=p_event and status='published') then raise exception 'Registration is not open'; end if;
 if p_idempotency is null or jsonb_typeof(p_answers)<>'object' or octet_length(p_answers::text)>20000 then raise exception 'Invalid registration'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text||p_event::text,0));
 h:=md5(jsonb_build_object('ticket',p_ticket,'name',p_name,'phone',p_phone,'organization',p_org,'answers',p_answers)::text);
 select * into existing from orders where buyer_user_id=u and idempotency_key=p_idempotency;
 if found then
 if existing.request_hash<>h then raise exception 'Registration request changed'; end if;
 select r.id into reg from registrations r join order_items i on i.id=r.order_item_id where i.order_id=existing.id;
 if reg is null then raise exception 'Request key already used'; end if; return reg;
 end if;
 person:=private.person(p_name,p_phone,p_org);
 if exists(select 1 from registrations where person_id=person and event_id=p_event and status not in ('rejected','cancelled')) then raise exception 'You already have a registration for this event'; end if;
 select * into form from registration_forms where event_id=p_event and active;
 if not found then raise exception 'Registration form is not published'; end if;
 for field in select * from jsonb_array_elements(form.fields) loop
 if coalesce((field->>'required')::boolean,false) and trim(coalesce(p_answers->>(field->>'key'),''))='' then raise exception 'Complete %',field->>'label'; end if;
 if length(coalesce(p_answers->>(field->>'key'),''))>2000 then raise exception 'Answer is too long'; end if;
 if field->>'type'='select' and coalesce(p_answers->>(field->>'key'),'')<>'' and not exists(select 1 from jsonb_array_elements_text(field->'options') opt where opt=p_answers->>(field->>'key')) then raise exception 'Invalid answer for %',field->>'label'; end if;
 end loop;
 select * into t from ticket_types where id=p_ticket and event_id=p_event for update;
 if not found or not t.active or t.capacity-t.reserved-t.allocated<1 then raise exception 'This ticket is unavailable or full'; end if;
 if t.price_minor>0 then
 select * into cfg from commerce_settings where event_id=p_event;
 if not found or coalesce(cfg.bank_details->>'account_number','')='' then raise exception 'Payment details are not configured'; end if;
 deadline:=now()+make_interval(hours=>cfg.payment_window_hours);
 insert into orders(event_id,buyer_user_id,buyer_person_id,total_minor,buyer_snapshot,bank_details_snapshot,payment_due_at,idempotency_key,request_hash)
 values(p_event,u,person,t.price_minor,jsonb_build_object('name',p_name,'phone',p_phone,'email',(select email from people where id=person)),cfg.bank_details,deadline,p_idempotency,h) returning id into o;
 insert into order_items(order_id,ticket_type_id,name_snapshot,variant_snapshot,quantity,unit_price_minor) values(o,t.id,t.name,'Delegate registration',1,t.price_minor) returning id into item;
 insert into stock_reservations(order_item_id,expires_at) values(item,deadline);
 insert into payments(order_id,amount_minor) values(o,t.price_minor);
 update ticket_types set reserved=reserved+1 where id=t.id;
 perform private.record_order(o,'registration_order_placed');
 else update ticket_types set allocated=allocated+1 where id=t.id; end if;
 insert into registrations(event_id,person_id,submitted_by,ticket_type_id,order_item_id,form_id,answers,status)
 values(p_event,person,u,t.id,item,form.id,p_answers,case when t.price_minor>0 then 'awaiting_payment' else 'submitted' end) returning id into reg;
 insert into audit_logs(event_id,actor_user_id,action,entity_id) values(p_event,u,'registration_submitted',reg);
 return reg;
end $$;
create or replace function public.review_registration(p_registration uuid,p_approve boolean,p_note text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r registrations%rowtype; o orders%rowtype; begin
 perform private.require_user();
 -- Lock order before registration to share the payment/expiry lock ordering.
 select ord.* into o from orders ord join order_items i on i.order_id=ord.id join registrations rr on rr.order_item_id=i.id where rr.id=p_registration for update of ord;
 select * into r from registrations where id=p_registration for update;
 if not found or not private.has_role(r.event_id,array['registration_manager']) then raise exception 'Registration access required'; end if;
 if r.status='confirmed' and p_approve then return; end if;
 if r.status not in ('submitted','awaiting_payment') then raise exception 'Registration cannot be reviewed'; end if;
 if length(trim(p_note))<3 then raise exception 'Enter a review note'; end if;
 if p_approve then
 if r.order_item_id is not null and (o.status is distinct from 'confirmed' or exists(select 1 from refunds rf join payments p on p.id=rf.payment_id where p.order_id=o.id)) then raise exception 'Approve payment before admitting the delegate'; end if;
 update registrations set status='confirmed',approved_at=now(),approved_by=auth.uid() where id=r.id;
 insert into delegates(registration_id) values(r.id) on conflict(registration_id) do nothing;
 else
 if o.status='confirmed' then raise exception 'Paid registrations need finance refund resolution before cancellation'; end if;
 if r.order_item_id is not null then perform private.release_order(o.id,'cancelled'); else update ticket_types set allocated=allocated-1 where id=r.ticket_type_id; end if;
 update registrations set status='rejected' where id=r.id;
 end if;
 insert into audit_logs(event_id,actor_user_id,action,entity_id,metadata) values(r.event_id,auth.uid(),case when p_approve then 'registration_approved' else 'registration_rejected' end,r.id,jsonb_build_object('note',p_note));
end $$;
create or replace function public.assign_delegate(p_delegate uuid,p_delegation uuid) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare ev uuid; begin
 select r.event_id into ev from delegates d join registrations r on r.id=d.registration_id where d.id=p_delegate;
 if ev is null or not private.has_role(ev,array['registration_manager']) then raise exception 'Registration access required'; end if;
 if p_delegation is not null and not exists(select 1 from delegations where id=p_delegation and event_id=ev) then raise exception 'Delegation belongs to another event'; end if;
 update delegates set delegation_id=p_delegation where id=p_delegate;
 insert into audit_logs(event_id,actor_user_id,action,entity_id,metadata) values(ev,auth.uid(),'delegate_assigned',p_delegate,jsonb_build_object('delegation_id',p_delegation));
end $$;
create or replace function public.check_in_delegate(p_event uuid,p_code text,p_checkpoint text) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare d record; begin
 if not private.has_role(p_event,array['registration_manager','checkin_staff']) then raise exception 'Check-in access required'; end if;
 if length(trim(p_checkpoint)) not between 1 and 80 then raise exception 'Enter a checkpoint'; end if;
 select dd.id,dd.delegate_number,p.full_name into d from delegates dd join registrations r on r.id=dd.registration_id join people p on p.id=r.person_id where r.event_id=p_event and r.status='confirmed' and (dd.badge_token=p_code or dd.delegate_number=upper(p_code));
 if not found then raise exception 'Confirmed delegate not found'; end if;
 insert into checkins(delegate_id,checkpoint,checked_in_by) values(d.id,trim(p_checkpoint),auth.uid()) on conflict(delegate_id,checkpoint) do nothing;
 return jsonb_build_object('name',d.full_name,'delegate_number',d.delegate_number,'checkpoint',p_checkpoint);
end $$;
create or replace function public.link_order_attendee(p_item uuid,p_registration uuid,p_quantity integer) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare i order_items%rowtype; ev uuid; begin
 select * into i from order_items where id=p_item for update;
 select event_id into ev from orders where id=i.order_id;
 if ev is null or not private.has_role(ev,array['shop_manager','registration_manager']) then raise exception 'Staff access required'; end if;
 if i.variant_id is null or not exists(select 1 from registrations where id=p_registration and event_id=ev and status='confirmed') then raise exception 'Select merchandise and a confirmed attendee in the same event'; end if;
 if p_quantity<0 or p_quantity is null or coalesce((select sum(quantity) from order_item_attendees where order_item_id=p_item and registration_id<>p_registration),0)+p_quantity>i.quantity then raise exception 'Allocation exceeds purchased quantity'; end if;
 if p_quantity=0 then delete from order_item_attendees where order_item_id=p_item and registration_id=p_registration;
 else insert into order_item_attendees values(p_item,p_registration,p_quantity) on conflict(order_item_id,registration_id) do update set quantity=excluded.quantity; end if;
 perform private.record_order(i.order_id,'attendee_merch_linked',jsonb_build_object('registration',p_registration,'quantity',p_quantity));
end $$;

-- Restrict every function explicitly, including all SECURITY DEFINER helpers.
revoke all on all functions in schema private from public,anon,authenticated;
grant usage on schema private to anon,authenticated;
grant execute on function private.has_role(uuid,text[]) to anon,authenticated;
grant execute on function private.owns_order(uuid),private.can_order(uuid,text[]) to authenticated;
do $$ declare f record; begin
 for f in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('save_cart','create_order','submit_receipt','review_payment','cancel_order','expire_unpaid_orders','record_collection','record_refund','admin_save','submit_registration','review_registration','assign_delegate','check_in_delegate','link_order_attendee') loop
 execute format('revoke all on function %s from public,anon,authenticated',f.signature);
 execute format('grant execute on function %s to authenticated,service_role',f.signature);
 end loop;
end $$;
