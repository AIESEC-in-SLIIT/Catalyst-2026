insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('payment-receipts','payment-receipts',false,10485760,array['image/jpeg','image/png','application/pdf']),
 ('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy receipt_upload on storage.objects for insert to authenticated with check(
 bucket_id='payment-receipts' and split_part(name,'/',1)=auth.uid()::text and exists(
 select 1 from public.payments p join public.orders o on o.id=p.order_id where p.id::text=split_part(name,'/',2)
 and o.buyer_user_id=auth.uid() and p.status='pending' and o.status='awaiting_payment' and o.payment_due_at>now()));
create policy receipt_view on storage.objects for select to authenticated using(
 bucket_id='payment-receipts' and exists(select 1 from public.payments p where p.id::text=split_part(name,'/',2) and private.can_order(p.order_id,array['finance'])));
create policy product_image_upload on storage.objects for insert to authenticated with check(bucket_id='product-images' and exists(select 1 from public.events where id::text=split_part(name,'/',1) and private.has_role(id,array['shop_manager'])));
create policy product_image_read on storage.objects for select using(bucket_id='product-images');

create or replace function public.shop_status(p_event uuid) returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('orders_open',s.orders_open,'pickup_instructions',s.pickup_instructions,'support_email',s.support_email)
 from commerce_settings s join events e on e.id=s.event_id where e.id=p_event and e.status='published';
$$;
revoke all on function public.shop_status(uuid) from public;
grant execute on function public.shop_status(uuid) to anon,authenticated;

insert into public.events(id,slug,name,status) values('ca202600-0000-4000-8000-000000000001','catalyst-2026','Catalyst 2026','published');
insert into public.commerce_settings(event_id) values('ca202600-0000-4000-8000-000000000001');
insert into public.products(event_id,slug,name,description,status,sort_order) values
 ('ca202600-0000-4000-8000-000000000001','wristbands','Wristbands','Small detail. Shared spirit.','active',1),
 ('ca202600-0000-4000-8000-000000000001','regular-tee','Regular Tee','Your everyday uniform.','active',2),
 ('ca202600-0000-4000-8000-000000000001','oversized-tee','Oversized Tee','More room. Same fearless spirit.','active',3),
 ('ca202600-0000-4000-8000-000000000001','sticker-pack','Sticker Pack','Leave your mark.','active',4),
 ('ca202600-0000-4000-8000-000000000001','bucket-hat','Bucket Hat','Top off your next chapter.','active',5);
insert into public.product_variants(product_id,sku,label)
 select id,upper(slug)||'-DEFAULT','Default' from public.products;
insert into public.inventory_balances(variant_id) select id from public.product_variants;
insert into public.registration_forms(event_id,version,fields) values('ca202600-0000-4000-8000-000000000001',1,'[]');
