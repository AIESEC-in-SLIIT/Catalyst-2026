-- Catalyst core. All purchasing writes pass through authenticated transactions.
create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.events (
 id uuid primary key default gen_random_uuid(), slug text unique not null, name text not null,
 status text not null default 'draft' check(status in ('draft','published','closed')),
 starts_at timestamptz, venue text, created_at timestamptz not null default now()
);
create table public.people (
 id uuid primary key default gen_random_uuid(), user_id uuid unique references auth.users(id),
 full_name text not null, email text not null, phone text not null default '', organization text not null default '',
 created_at timestamptz not null default now()
);
create table public.staff_memberships (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id), event_id uuid references public.events,
 role text not null check(role in ('owner','finance','shop_manager','registration_manager','checkin_staff')),
 active boolean not null default true, created_at timestamptz not null default now(),
 check(event_id is not null or role='owner')
);
create unique index staff_event_role on public.staff_memberships(user_id,event_id,role) where event_id is not null;
create unique index staff_global_owner on public.staff_memberships(user_id) where event_id is null;
create table public.commerce_settings (
 event_id uuid primary key references public.events, orders_open boolean not null default false,
 bank_details jsonb not null default '{}', pickup_instructions text not null default '', support_email text not null default '',
 payment_window_hours integer not null default 24 check(payment_window_hours between 1 and 168),
 review_window_hours integer not null default 48 check(review_window_hours between 1 and 336)
);
create table public.products (
 id uuid primary key default gen_random_uuid(), event_id uuid not null references public.events,
 slug text not null, name text not null, description text not null default '', image_path text,
 status text not null default 'draft' check(status in ('draft','active','archived')), sort_order integer not null default 0,
 created_at timestamptz not null default now(), unique(event_id,slug)
);
create table public.product_variants (
 id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products,
 sku text unique not null, label text not null, options jsonb not null default '{}',
 price_minor bigint check(price_minor > 0), currency text not null default 'LKR' check(currency='LKR'),
 active boolean not null default false, max_per_order integer not null default 5 check(max_per_order between 1 and 100)
);
create table public.inventory_balances (
 variant_id uuid primary key references public.product_variants, on_hand integer not null default 0, reserved integer not null default 0,
 check(on_hand>=reserved and reserved>=0)
);
create table public.carts (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users, event_id uuid not null references public.events,
 items jsonb not null default '[]' check(jsonb_typeof(items)='array'), updated_at timestamptz not null default now(), unique(user_id,event_id)
);
create table public.ticket_types (
 id uuid primary key default gen_random_uuid(), event_id uuid not null references public.events, name text not null,
 price_minor bigint not null default 0 check(price_minor>=0), capacity integer not null default 0,
 reserved integer not null default 0, allocated integer not null default 0, active boolean not null default false,
 check(reserved>=0 and allocated>=0 and capacity>=reserved+allocated)
);
create table public.registration_forms (
 id uuid primary key default gen_random_uuid(), event_id uuid not null references public.events, version integer not null,
 fields jsonb not null default '[]' check(jsonb_typeof(fields)='array'), active boolean not null default false,
 created_at timestamptz not null default now(), unique(event_id,version)
);
create unique index active_event_form on public.registration_forms(event_id) where active;
create table public.orders (
 id uuid primary key default gen_random_uuid(), order_number text unique not null default ('CAT-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12))),
 event_id uuid not null references public.events, buyer_user_id uuid not null references auth.users, buyer_person_id uuid not null references public.people,
 status text not null default 'awaiting_payment' check(status in ('awaiting_payment','payment_review','confirmed','expired','cancelled')),
 total_minor bigint not null check(total_minor>0), currency text not null default 'LKR' check(currency='LKR'),
 buyer_snapshot jsonb not null, bank_details_snapshot jsonb not null, payment_due_at timestamptz not null,
 confirmed_at timestamptz, idempotency_key uuid not null, request_hash text not null, created_at timestamptz not null default now(),
 unique(buyer_user_id,idempotency_key)
);
create table public.order_items (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders,
 variant_id uuid references public.product_variants, ticket_type_id uuid references public.ticket_types,
 name_snapshot text not null, variant_snapshot text not null, sku_snapshot text,
 quantity integer not null check(quantity>0), unit_price_minor bigint not null check(unit_price_minor>=0),
 line_total_minor bigint generated always as (quantity*unit_price_minor) stored,
 check(num_nonnulls(variant_id,ticket_type_id)=1)
);
create table public.stock_reservations (
 id uuid primary key default gen_random_uuid(), order_item_id uuid unique not null references public.order_items,
 expires_at timestamptz not null, status text not null default 'held' check(status in ('held','committed','released'))
);
create table public.inventory_movements (
 id uuid primary key default gen_random_uuid(), variant_id uuid not null references public.product_variants,
 order_item_id uuid references public.order_items, on_hand_delta integer not null, reserved_delta integer not null,
 reason text not null, actor_user_id uuid references auth.users, created_at timestamptz not null default now()
);
create table public.payments (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders,
 method text not null default 'bank_transfer' check(method='bank_transfer'), amount_minor bigint not null check(amount_minor>0),
 status text not null default 'pending' check(status in ('pending','submitted','approved','rejected','expired')),
 bank_reference text, review_note text, reviewed_by uuid references auth.users, reviewed_at timestamptz,
 created_at timestamptz not null default now()
);
create unique index one_live_payment on public.payments(order_id) where status in ('pending','submitted','approved');
create table public.payment_receipts (
 id uuid primary key default gen_random_uuid(), payment_id uuid not null references public.payments,
 uploaded_by uuid not null references auth.users, storage_path text unique not null,
 created_at timestamptz not null default now()
);
create table public.refunds (
 id uuid primary key default gen_random_uuid(), payment_id uuid not null references public.payments,
 amount_minor bigint not null check(amount_minor>0), bank_reference text not null, reason text not null,
 processed_by uuid not null references auth.users, idempotency_key uuid unique not null, created_at timestamptz not null default now()
);
create table public.fulfillments (
 id uuid primary key default gen_random_uuid(), order_id uuid unique not null references public.orders,
 status text not null default 'pending' check(status in ('pending','ready','partially_collected','collected')),
 pickup_code text unique not null default upper(substr(replace(gen_random_uuid()::text,'-',''),1,16)), created_at timestamptz not null default now()
);
create table public.fulfillment_items (
 id uuid primary key default gen_random_uuid(), fulfillment_id uuid not null references public.fulfillments,
 order_item_id uuid unique not null references public.order_items, quantity integer not null,
 collected_quantity integer not null default 0, check(quantity>0 and collected_quantity between 0 and quantity)
);
create table public.order_events (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders, event_type text not null,
 actor_user_id uuid references auth.users, metadata jsonb not null default '{}', created_at timestamptz not null default now()
);
create table public.registrations (
 id uuid primary key default gen_random_uuid(), event_id uuid not null references public.events,
 person_id uuid not null references public.people, submitted_by uuid not null references auth.users,
 ticket_type_id uuid not null references public.ticket_types, order_item_id uuid unique references public.order_items,
 form_id uuid not null references public.registration_forms, answers jsonb not null default '{}',
 status text not null default 'submitted' check(status in ('submitted','awaiting_payment','confirmed','rejected','cancelled')),
 approved_at timestamptz, approved_by uuid references auth.users, created_at timestamptz not null default now()
);
create unique index one_active_registration on public.registrations(event_id,person_id) where status not in ('rejected','cancelled');
create table public.delegations (
 id uuid primary key default gen_random_uuid(), event_id uuid not null references public.events, name text not null,
 organization text not null default '', unique(event_id,name)
);
create table public.delegates (
 id uuid primary key default gen_random_uuid(), registration_id uuid unique not null references public.registrations,
 delegation_id uuid references public.delegations, delegate_number text unique not null default ('DEL-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
 badge_token text unique not null default encode(extensions.gen_random_bytes(24),'hex'), created_at timestamptz not null default now()
);
create table public.checkins (
 id uuid primary key default gen_random_uuid(), delegate_id uuid not null references public.delegates,
 checkpoint text not null, checked_in_by uuid not null references auth.users, created_at timestamptz not null default now(), unique(delegate_id,checkpoint)
);
create table public.order_item_attendees (
 order_item_id uuid not null references public.order_items, registration_id uuid not null references public.registrations,
 quantity integer not null check(quantity>0), primary key(order_item_id,registration_id)
);
create table public.audit_logs (
 id uuid primary key default gen_random_uuid(), event_id uuid references public.events, actor_user_id uuid references auth.users,
 action text not null, entity_id uuid, metadata jsonb not null default '{}', created_at timestamptz not null default now()
);
-- Durable business notifications only. No email provider, sender, worker, or queue is deployed.
create table public.notification_events (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users, event_id uuid not null references public.events,
 order_id uuid references public.orders, type text not null, message text not null, dedupe_key text unique not null,
 created_at timestamptz not null default now()
);

create or replace function private.has_role(p_event uuid, p_roles text[] default array['owner','finance','shop_manager','registration_manager'])
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from staff_memberships where user_id=auth.uid() and active and
 ((role='owner' and (event_id is null or event_id=p_event)) or (event_id=p_event and role=any(p_roles))));
$$;
create or replace function private.owns_order(p_order uuid) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from orders where id=p_order and buyer_user_id=auth.uid());
$$;
create or replace function private.can_order(p_order uuid,p_roles text[] default array['owner','finance','shop_manager']) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from orders where id=p_order and (buyer_user_id=auth.uid() or private.has_role(event_id,p_roles)));
$$;
revoke all on all functions in schema private from public;
grant execute on all functions in schema private to authenticated;

-- RLS is enabled before granting any access.
do $$ declare t text; begin
 foreach t in array array['events','people','staff_memberships','commerce_settings','products','product_variants','inventory_balances','carts','ticket_types','registration_forms','orders','order_items','stock_reservations','inventory_movements','payments','payment_receipts','refunds','fulfillments','fulfillment_items','order_events','registrations','delegations','delegates','checkins','order_item_attendees','audit_logs','notification_events'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon, authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
 end loop;
end $$;
grant select on public.events,public.products,public.product_variants,public.ticket_types,public.registration_forms to anon;
create policy public_events on public.events for select using(status='published' or (auth.uid() is not null and private.has_role(id)));
create policy people_read on public.people for select to authenticated using(user_id=auth.uid() or exists(select 1 from public.orders o where o.buyer_person_id=people.id and private.has_role(o.event_id)) or exists(select 1 from public.registrations r where r.person_id=people.id and private.has_role(r.event_id,array['registration_manager','checkin_staff'])));
create policy memberships_read on public.staff_memberships for select to authenticated using(user_id=auth.uid() or private.has_role(event_id,array['owner']));
create policy settings_read on public.commerce_settings for select to authenticated using(private.has_role(event_id,array['owner','finance','shop_manager']));
create policy products_read on public.products for select using((status='active' and exists(select 1 from public.events e where e.id=event_id and e.status='published')) or (auth.uid() is not null and private.has_role(event_id,array['shop_manager'])));
create policy variants_read on public.product_variants for select using(exists(select 1 from public.products p where p.id=product_id and ((active and p.status='active') or (auth.uid() is not null and private.has_role(p.event_id,array['shop_manager'])))));
create policy inventory_read on public.inventory_balances for select to authenticated using(exists(select 1 from public.product_variants v join public.products p on p.id=v.product_id where v.id=variant_id and private.has_role(p.event_id,array['shop_manager'])));
create policy carts_owner on public.carts for select to authenticated using(user_id=auth.uid());
create policy tickets_read on public.ticket_types for select using((active and exists(select 1 from public.events e where e.id=event_id and e.status='published')) or (auth.uid() is not null and private.has_role(event_id,array['registration_manager'])));
create policy forms_read on public.registration_forms for select using((active and exists(select 1 from public.events e where e.id=event_id and e.status='published')) or (auth.uid() is not null and private.has_role(event_id,array['registration_manager'])));
create policy orders_read on public.orders for select to authenticated using(buyer_user_id=auth.uid() or private.has_role(event_id,array['finance','shop_manager','registration_manager']));
create policy items_read on public.order_items for select to authenticated using(private.can_order(order_id,array['finance','shop_manager','registration_manager']));
create policy reservations_read on public.stock_reservations for select to authenticated using(exists(select 1 from public.order_items i where i.id=order_item_id and private.can_order(i.order_id)));
create policy movements_read on public.inventory_movements for select to authenticated using(exists(select 1 from public.product_variants v join public.products p on p.id=v.product_id where v.id=variant_id and private.has_role(p.event_id,array['shop_manager'])));
create policy payments_read on public.payments for select to authenticated using(private.can_order(order_id,array['finance']));
create policy receipts_read on public.payment_receipts for select to authenticated using(exists(select 1 from public.payments p where p.id=payment_id and private.can_order(p.order_id,array['finance'])));
create policy refunds_read on public.refunds for select to authenticated using(exists(select 1 from public.payments p where p.id=payment_id and private.can_order(p.order_id,array['finance'])));
create policy fulfillment_read on public.fulfillments for select to authenticated using(private.can_order(order_id));
create policy fulfillment_items_read on public.fulfillment_items for select to authenticated using(exists(select 1 from public.fulfillments f where f.id=fulfillment_id and private.can_order(f.order_id)));
create policy order_events_read on public.order_events for select to authenticated using(private.can_order(order_id));
create policy registration_read on public.registrations for select to authenticated using(submitted_by=auth.uid() or private.has_role(event_id,array['registration_manager','checkin_staff']));
create policy delegation_read on public.delegations for select to authenticated using(private.has_role(event_id,array['registration_manager','checkin_staff']));
create policy delegate_read on public.delegates for select to authenticated using(exists(select 1 from public.registrations r where r.id=registration_id and (r.submitted_by=auth.uid() or private.has_role(r.event_id,array['registration_manager']))));
create policy checkin_read on public.checkins for select to authenticated using(exists(select 1 from public.delegates d join public.registrations r on r.id=d.registration_id where d.id=delegate_id and private.has_role(r.event_id,array['registration_manager','checkin_staff'])));
create policy allocations_read on public.order_item_attendees for select to authenticated using(exists(select 1 from public.order_items i where i.id=order_item_id and private.can_order(i.order_id)));
create policy audit_read on public.audit_logs for select to authenticated using(private.has_role(event_id,array['owner']));
create policy notifications_read on public.notification_events for select to authenticated using(user_id=auth.uid());

-- Indexed ownership, review queues and foreign keys.
create index orders_event_created on public.orders(event_id,created_at desc);
create index orders_buyer_created on public.orders(buyer_user_id,created_at desc);
create index orders_expiry on public.orders(payment_due_at) where status in ('awaiting_payment','payment_review');
create index people_email on public.people(lower(email));
create index items_order on public.order_items(order_id);
create index payments_order on public.payments(order_id);
create index payments_queue on public.payments(status,created_at);
create index registrations_event on public.registrations(event_id,created_at desc);
create index registrations_person on public.registrations(person_id);
create index receipts_payment on public.payment_receipts(payment_id);
create index movements_variant on public.inventory_movements(variant_id,created_at desc);
create index products_event on public.products(event_id);
create index variants_product on public.product_variants(product_id);
create index notification_owner on public.notification_events(user_id,created_at desc);
