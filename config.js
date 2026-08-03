/* ============================================================
   REV NATION JAIPUR — Supabase configuration
   Fill these in once your Supabase project exists (see
   SETUP-GUIDE.md). Until then, the main site runs on its
   built-in placeholder content and admin.html will show a
   "not configured" notice instead of a login form.
   ============================================================ */
window.REV_NATION_CONFIG = {
  SUPABASE_URL: "https://ipbrvwrfatcbvrmvsyd.supabase.co",     // project URL from Supabase dashboard
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlwYnJ2d3JmYW90Y2J2cm12c3lkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MDY4MjIsImV4cCI6MjEwMTI4MjgyMn0.l7hGKKFwgwNzcHKrXipd0OS3PCmTToNbkGVKVXLmSVs",    // Project Settings → API → anon public key
  TURNSTILE_SITE_KEY: "YOUR_TURNSTILE_SITE_KEY"    // dash.cloudflare.com → Turnstile → Add Widget → copy the public Site Key (starts with 0x…)
};
