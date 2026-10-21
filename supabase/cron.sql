-- Run once in the Supabase SQL editor after enabling Integrations > Cron.
-- The job is owned by the SQL editor's postgres role; browser roles cannot
-- call private.expire_all_orders directly.
select cron.schedule(
 'catalyst-expire-reservations',
 '*/5 * * * *',
 'select private.expire_all_orders()'
);
