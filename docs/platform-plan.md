# Catalyst Supabase setup and launch

The frontend and SQL are prepared in this repository. A new Supabase project has not yet been linked, so migrations have not been applied to a live database.

## Connect the project

1. Create separate development and production Supabase projects. Link the Supabase CLI to the development project and apply the files in `supabase/migrations/` in filename order. Review the migration diff before applying it to production.
2. Put the project URL and **publishable** key in `.env.local` as `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`. Keep the service role key out of this repository and every Vite variable.
3. Configure Auth URL settings for the deployed site's `/account/` callback. Enable email sign-in and set up production SMTP through Supabase Auth. Supabase's default SMTP is intended for development and only sends to authorized team addresses at a very low rate ([Supabase Auth SMTP guide](https://supabase.com/docs/guides/auth/auth-smtp)).
4. Have the first owner sign in once and verify their email. In the Supabase SQL editor, find that user's UUID in `auth.users`, then grant a global owner membership:

```sql
insert into public.staff_memberships (user_id, event_id, role)
select id, null, 'owner' from auth.users where email = 'owner@example.com'
on conflict (user_id) where event_id is null do update set active = true;
```

5. Enable **Integrations → Cron** in Supabase, then run `supabase/cron.sql` in the SQL editor. It releases unpaid reservations every five minutes. Monitor the job in the Cron dashboard ([Supabase Cron guide](https://supabase.com/docs/guides/cron)).
6. Set the GitHub repository variables `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`. The production workflow passes them to Vite during the Pages build.

## Configure before selling

In `/admin/`, set each product variant's SKU, size or option, price in LKR, max quantity and stock. Configure the bank name, account name, account number, support email, and event pickup instructions. Then open checkout in Settings. The seed keeps all variants inactive and checkout closed until you do this.

The flow is: add to bag → verify email → place order → transfer funds → upload JPG/PNG/PDF receipt (10 MB max) → finance verifies the bank credit and approves or rejects → staff mark the order ready and record collection. Receipt uploads are private. RLS and database functions enforce ownership and staff roles. Orders and reservations are created in one transaction; duplicate checkout retries use an idempotency key.

Registration forms and ticket types can be published from the admin panel. A confirmed delegate can be assigned to a delegation and checked in by badge code. Paid registration approvals require approved payment first.

## Deferred email work

Order status changes write to `notification_events` for account updates. Transactional order emails and their delivery worker are intentionally deferred. Supabase Auth handles sign-in email after SMTP is configured. Supabase Auth does not act as a general order-email sender; that later phase needs a dedicated sending path.

Before launch, verify concurrent last-unit checkout, duplicate requests, receipt privacy, payment review, reservation expiry, refund and collection handling, role scopes, direct Page URLs, and mobile checkout on the connected project.
