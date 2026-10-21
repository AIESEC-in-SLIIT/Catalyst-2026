# CATALYST 2026

The CATALYST site for AIESEC in SLIIT. The published home route shows an under-construction screen; `/marketplace/` is the live storefront preview. The shop presents five merch concepts with a touch and wheel controlled circular carousel, petals, motion controls, and product previews.

## Develop

Requires Node.js 22.12 or newer.

```sh
npm ci
npm run dev
```

Pages are explicit Vite entries: `/marketplace/`, `/checkout/`, `/account/`, `/registrations/`, and `/admin/`. The home page and presentation are in `index.html`, `styles.css`, and `src/hero.jsx`. Marketplace motion is in `src/marketplace.js` and `src/marketplace.css`. Supabase UI is in `src/platform/`.

Build with `npm run build`. The GitHub Pages workflow deploys `dist/` when `production` is pushed. In GitHub Settings → Pages, select **GitHub Actions** as the build source.

## Supabase platform

Versioned SQL migrations in `supabase/migrations/` define the shop, manual bank transfer checkout, private receipt uploads, finance review, inventory reservations, collection, staff access, and registration/delegate records. The admin panel includes event overview, orders, payments, products, stock, registrations, delegates, tickets, forms, delegations, check-in, staff, settings, and audit history.

Copy `.env.example` to `.env.local` and add only the project URL and publishable key. The service role key must never be put in Vite or GitHub Pages variables. Production Pages builds read `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` from GitHub repository variables.

New projects seed five products with inactive, unpriced variants, zero stock, and checkout closed. Follow [the setup guide](docs/platform-plan.md) to apply migrations, enable auth delivery, add the first owner, configure prices, bank details and pickup, and schedule reservation expiry. Checkout cannot open without those steps. Order email delivery is reserved for a later phase; in-app order updates are already recorded.

## Motion

The React hero uses a scrubbed GSAP timeline and layered SVG artwork. The marketplace carousel accepts wheel, trackpad, touch, buttons, and product tabs. Touch gestures follow the ring angle, settle on a card, and emit petals according to rotation speed. Reduced-motion preferences disable ambient motion.
