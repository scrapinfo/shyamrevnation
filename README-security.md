# 🔐 Rev Nation Studio — Complete Secure Setup

This folder now connects to your **new Supabase project** (host: `ipbrvwrfatcbvrmvsyd`). Use this guide in order — about 15 minutes total.

---

## Step 1 — Create the database from scratch

This single SQL builds everything: all your site's data tables, the three security tables, all functions, all policies, plus seeds your 6 homepage stats.

1. Open your new Supabase project → **SQL Editor** (left sidebar)
2. Click **+ New Query**
3. Open **`setup-security.sql`** in this folder, copy the **entire file**, paste it in
4. Click **Run**

✅ Expected: `Success. No rows returned`

This one script replaces all 8 of your previous `supabase sql.txt` chunks — it's the only one you ever need to run.

---

## Step 2 — Create your admin user (login credentials)

1. Go to **Authentication** → **Users**
2. Click **Add User**
3. Use a strong email + password combo (16+ characters)
4. Click **Create user**

⚡ You'll use this to log in to `studio-gate-88.html`.

---

## Step 3 — Mark that user as an "admin" (the critical step)

This is what makes you the ONLY person who can open the panel. RLS checks this.

1. Still in **Authentication** → **Users**, click your new user
2. Copy the **UUID** at the top (looks like `a1b2c3d4-...`)
3. Go back to **SQL Editor** → New Query, run this (replace the UUID):

```sql
INSERT INTO admins (id) VALUES ('paste-your-uuid-here');
```

✅ Done. Your account is now registered as an admin.

---

## Step 4 — Get your free Cloudflare Turnstile key (CAPTCHA)

This stops brute-force bots from attacking the login.

1. Go to https://dash.cloudflare.com → log in / free signup
2. Left sidebar → **Turnstile** → **Add Widget**
3. Set:
   - **Name:** `Rev Nation`
   - **Widget type:** **Managed**
   - **Hostname:** add BOTH:
     - `your-live-domain.com`
     - `localhost` (*important for testing*)
4. Click **Create**
5. Copy the **Site Key** (starts with `0x4AAAAAAA...`)

Paste it into `config.js`:

```js
TURNSTILE_SITE_KEY: "0x4AAAAAAA_your_key_here"
```

---

## Step 5 — Harden your Supabase dashboard (2-minute toggles)

In Supabase → **Authentication**:

1. **Providers** → Email → Toggle **OFF** "Allow new users to sign up"
   - Prevents attackers from creating their own free user accounts
2. **General Settings** → Toggle **ON** "Confirm email"
   - Standard practice, only applies going forward

---

## ✅ Verify it's all working

```bash
# From this folder, serve locally:
python -m http.server 8000
# then open:
#   http://localhost:8000/studio-gate-88.html  ← admin
#   http://localhost:8000/index.html          ← homepage
```

You should see:
- ✅ **Login form with a CAPTCHA** at the top
- ✅ Sign In button disabled until you solve the CAPTCHA
- ✅ Test: type wrong password 6 times → locked for 15 min
- ✅ Inside the panel: new **"Audit Log"** tab lists your attempts with your IP + timestamp
- ✅ Leads show: `03 Aug 2026, 14:32 • 🕐 5 min ago`

---

## 📜 What the SQL script actually gives you

| Layer | What you got | Where |
|-------|--------------|-------|
| **Data tables** | leads, projects, testimonials, stats, site_media, frame_sequences | `Block 1` of setup-security.sql |
| **Security tables** | admins, login_attempts, activity_log | `Block 2` |
| **Functions** | `is_admin()`, `get_client_ip()`, `check_login_allowed()`, `log_login_attempt()` | `Block 3` |
| **Storage buckets** | project-images, site-assets, frame-sequences (public read) | `Block 4` |
| **RLS** | Strict — public can only read site content, everything else admin-only | `Block 5` |
| **Seeds** | Default stats that populate your homepage counters | `Block 6` |

---

## 🧠 The security model in plain English

- Your `SUPABASE_ANON_KEY` is public by design (it's in every browser).
- What makes it safe now: **RLS policies** say the public key can only do 3 things:
  - Read published site content (projects, testimonials, stats, etc.)
  - Insert into `leads` (the contact form — no reading back)
  - Log a login attempt (needed for the rate limiter)
- Anything else — viewing leads, deleting projects, uploading images, reading audit logs — requires being **both** logged in AND in the `admins` table.
- Your admin credentials are checked by Supabase Auth; only your specific UUID gets past `is_admin()`.

Even if someone steals your anon key: they see content, they can't change anything.

---

## 🆘 Common issues

| Symptom | Fix |
|--------|-----|
| CAPTCHA not rendering | Add `localhost` AND your live domain to Turnstile. Confirm `TURNSTILE_SITE_KEY` is set |
| "Too many failed attempts" when testing | Wait 15 min OR open DevTools → Application → Session Storage → delete `rn_login_lock_v1` |
| Login succeeds but can't see leads | You didn't run the `INSERT INTO admins` step |
| Old leads aren't showing | `loadLeads()` sorts by `created_at DESC` — refreshes on tab change. Check Supabase → Table Editor → leads |
| "Permission denied" errors | RLS is working! Confirm you're logged in AND your user is in `admins` |

---

## 🛠️ Files in this folder (latest)

| File | Purpose |
|------|---------|
| `index.html` | Your live homepage — now with Turnstile + honeypot spam shield on the booking form |
| `studio-gate-88.html` | **New secure admin panel** (CAPTCHA + rate limits + audit tab) |
| `config.js` | Supabase + Turnstile keys — edit the Site Key after Step 4 |
| `setup-security.sql` | The ONE script to rule them all (blocks 1–6) |
| `README-security.md` | This file |
| `plan.md` | Technical design notes (can delete) |
