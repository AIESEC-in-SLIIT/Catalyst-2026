# Catalyst platform schema

The executable source of truth is `supabase/migrations/`. The schema is designed for multiple Catalyst editions through `events`; the seed creates `catalyst-2026`.

| Area | Main tables | Access and transaction rules |
| --- | --- | --- |
| Identity and staff | `people`, `staff_memberships`, `events` | Verified Supabase Auth identities; event scoped staff roles; global owner bootstrap |
| Shop | `products`, `product_variants`, `inventory_balances`, `inventory_movements`, `carts` | Public active catalog; staff edits through `admin_save`; stock ledger |
| Orders | `orders`, `order_items`, `stock_reservations`, `payments`, `payment_receipts`, `refunds` | Customer ownership via RLS; atomic checkout and review functions; private receipts |
| Pickup | `fulfillments`, `fulfillment_items` | Confirmed orders only; ready and collected states with quantity checks |
| Registration | `ticket_types`, `registration_forms`, `registrations`, `delegates`, `delegations`, `checkins`, `order_item_attendees` | Versioned forms, capacity reservations, approval, delegation, badge check-in |
| History | `order_events`, `audit_logs`, `notification_events` | Append-only transition history and in-app notices |

Money is stored in integer minor units (LKR cents). Merchandise and ticket inventory are reserved before bank transfer and committed only after finance approval. The Cron job releases expired unpaid reservations. The database functions are `SECURITY DEFINER` with explicit authorization checks, restricted grants, and a fixed search path. Browser code uses the publishable key only; every sensitive write goes through a role checked function.

The first four migrations create tables, policies, storage buckets, functions, and seed products. Migration 005 adds event scoped overview totals. Migration 006 adds the private reservation expiry function. `supabase/cron.sql` schedules it after Cron is enabled.
