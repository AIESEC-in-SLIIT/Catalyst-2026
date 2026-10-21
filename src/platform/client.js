import { createClient } from '@supabase/supabase-js';
const url = import.meta.env.VITE_SUPABASE_URL;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
export const configured = Boolean(url && key);
export const db = configured ? createClient(url, key, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } }) : null;
export const eventSlug = import.meta.env.VITE_EVENT_SLUG || 'catalyst-2026';
export const money = value => new Intl.NumberFormat('en-LK', { style: 'currency', currency: 'LKR' }).format(Number(value || 0) / 100);
// All new pages are explicit directory entries, so Pages can serve deep links directly.
export function route(page, query = '') {
  const path = location.pathname.replace(/(?:marketplace|checkout|account|admin|registrations)\/(?:index\.html)?$/, '');
  return `${path.endsWith('/') ? path : path + '/'}${page}/${query}`;
}
export async function rpc(name, args) {
  if (!db) throw new Error('The shop is getting ready. Please check back soon.');
  const { data, error } = await db.rpc(name,args);
  if (error) throw new Error(error.message);
  return data;
}
export async function rows(table, configure = q => q) {
  const { data, error } = await configure(db.from(table).select('*'));
  if (error) throw new Error(error.message);
  return data;
}
let catalogPromise;
export function catalog(refresh = false) {
  if (!configured) return Promise.resolve({ event: null, products: [], status: { orders_open: false } });
  if (refresh) catalogPromise = null;
  return catalogPromise ||= (async () => {
    const events = await rows('events',q=>q.eq('slug',eventSlug).limit(1));
    const event = events[0];
    if (!event) throw new Error('The collection is not available yet.');
    const { data: products,error } = await db.from('products').select('*,product_variants(*)').eq('event_id',event.id).eq('status','active').order('sort_order');
    if (error) throw new Error(error.message);
    const status = await rpc('shop_status',{p_event:event.id});
    return { event, products, status: status || { orders_open: false } };
  })().catch(error => { catalogPromise = null; throw error; });
}
const cartKey = 'catalyst-cart-v1';
export function getCart() {
  try { const items = JSON.parse(localStorage.getItem(cartKey) || '[]'); return Array.isArray(items) ? items.filter(i=>i && typeof i.variant_id==='string' && Number.isInteger(i.quantity) && i.quantity>0).slice(0,30) : []; } catch { return []; }
}
export function setCart(items) {
  localStorage.setItem(cartKey,JSON.stringify(items));
  window.dispatchEvent(new Event('cart-changed'));
}
export async function saveCart() {
  if (!db) return;
  const { data:{session} }=await db.auth.getSession();
  if (!session) return;
  const { event }=await catalog();
  if (event) await rpc('save_cart',{p_event:event.id,p_items:getCart()});
}
export function addItem(variant, product, quantity=1) {
  const items=getCart(); const existing=items.find(i=>i.variant_id===variant.id);
  const total=(existing?.quantity||0)+quantity;
  if (total>variant.max_per_order) throw new Error(`Maximum ${variant.max_per_order} per order for this option.`);
  if(existing) existing.quantity=total;
  else items.push({variant_id:variant.id,quantity,name:product.name,label:variant.label,price_minor:variant.price_minor});
  setCart(items);
}
export function readable(status) { return (status||'').replaceAll('_',' '); }
