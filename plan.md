# Secure Rev Nation Studio Admin — Implementation Plan

## What gets built
You keep your entire existing admin panel design & every feature, but with these upgrades:
1. **Cloudflare Turnstile CAPTCHA** on admin login + public booking form (free, unlimited)
2. **Rate limiting** on both forms (5 failures → 15 min lock, enforced client-side + DB-side)
3. **All-seeing audit trail:** every login attempt w/ IP address & timestamp, every panel action, browsable in a new "Audit" tab
4. **Leads with full details:** date + time + "5 min ago" badge, plus search/filter
5. **Admin role locking** so only YOUR specific Supabase account can touch the DB — not just anyone who makes a free user account
6. **Spam shield on the live booking form** (honeypot + CAPTCHA)
7. Session timeout, generic error messages, and cross-tab logout sync

## Files created/modified
1. **`studio-gate-88.html`** — rewritten (this is your new secure admin panel file)
2. **`setup-security.sql`** — NEW. You run this in Supabase SQL Editor ONCE
3. **`README-security.md`** — NEW. Your step-by-step setup guide
4. **`config.js`** — 1 new line added (`TURNSTILE_SITE_KEY`)
5. **`index.html`** — small patch to booking form (honeypot + CAPTCHA; zero visual change)

Now the detailed steps:

---

### STEP 1 — `setup-security.sql` (idempotent — safe to run multiple times; NO data loss)

Five SQL blocks wrapped in a transaction so either everything succeeds or nothing changes:

**Block 1: Admin role system**
```sql
CREATE TABLE IF NOT EXISTS admins (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);

CREATE OR REPLACE FUNCTION is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$ SELECT EXISTS(SELECT 1 FROM public.admins WHERE id = auth.uid()) $$;
```

**Block 2: Security + audit tables (with IP tracking)**
```sql
CREATE TABLE IF NOT EXISTS login_attempts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  email text NOT NULL,
  success boolean NOT NULL,
  ip_address text,
  user_agent text,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX ON login_attempts(email, created_at DESC);

CREATE TABLE IF NOT EXISTS activity_log (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  actor_email text, action text, target_table text, target_id text,
  ip_address text, created_at timestamptz DEFAULT now()
);
```

**Block 3: IP detection + rate limit functions**
```sql
CREATE OR REPLACE FUNCTION get_client_ip() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog
AS $$ SELECT host(inet_client_addr()) $$;

CREATE OR REPLACE FUNCTION check_login_allowed(p_email text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public AS $$
BEGIN
  RETURN (SELECT count(*) FROM login_attempts
          WHERE email = lower(p_email)
            AND success = false
            AND created_at > now() - interval '15 minutes') < 5;
END $$;

CREATE OR REPLACE FUNCTION log_login_attempt(p_email text, p_success boolean, p_user_agent text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public AS $$
BEGIN
  INSERT INTO login_attempts(email, success, ip_address, user_agent, created_at)
  VALUES (lower(p_email), p_success, get_client_ip(), p_user_agent, now());
END $$;
```

**Block 4: Replace ALL RLS policies (clean slate using DROP/CREATE).**
Public access stays for core site content, anything sensitive is locked behind `is_admin()`.

| Table | SELECT (public) | INSERT (public) | INSERT/UPDATE/DELETE |
|-------|----------------|----------------|---------------------|
| `leads` | ❌ | ✅ (booking form must work) | admin only |
| `projects` | ✅ | ❌ | admin only |
| `testimonials` | ✅ | ❌ | admin only |
| `stats` | ✅ | ❌ | admin only |
| `site_media` | ✅ | ❌ | admin only |
| `frame_sequences` | ✅ | ❌ | admin only |
| `admins` | admin only | ❌ | service_role only |
| `login_attempts` | admin only | ✅ (needed to rate limit) | admin only |
| `activity_log` | admin only | ✅ | admin only |

### STEP 2 — `studio-gate-88.html` (full rewrite)

**A. Login gate gets:**
- Turnstile widget inserted in the login form (dark theme, compact size, styled to match your design). Button disabled until CAPTCHA returns a token.
- Before `signInWithPassword`, two checks:
  1. CAPTCHA solved → else "Complete the security check."
  2. `rpc('check_login_allowed', email)` returns true → else "Too many failed attempts. Try again in X minutes."
- On login attempt (regardless of pass/fail) → `rpc('log_login_attempt', ...)` to record IP, email, success, user_agent.
- Client lockout: 5 failures in `sessionStorage` → 15 min enforced + exponential backoff bonus layers (10s, 30s, 90s delays). Cleared on successful login.
- Generous but safe session rules:
  - Inactivity timeout: **60 minutes**. On timeout, `signOut()` + show "Session expired. Please sign in again."
  - `storage` event listener for cross-tab logout: signing out in one tab kills all tabs.
  - Email shown in header as `a***@domain.com` (masked), hover reveals full.

**B. Leads tab upgrade**
- New "Received" column showing both:
  - Big line: `03 Aug 2026`
  - Below it: `, 14:32 • 🕐 5 min ago`
- Search box (matches across name/phone/car/message)
- Status filter chips: All | New | Contacted | Closed
- Every render shows "Last refreshed: [time]" so you know the data's fresh

**C. New "Audit" tab** (admin-only Nth tab)
Two stacked tables:
- **Login Attempts**: timestamp, masked email, ✅/❌, IP address, browser info
- **Activity Log**: timestamp, actor email, action (e.g. "delete on projects"), target ID

**D. Add `logActivity(action, target_table, target_id)` helper**
Called after every delete/status-update/upload in existing code paths. Only logs when action succeeds. Example: after deleting a project, adds "delete" + "projects" + project ID to activity_log.

**E. All existing functionality preserved verbatim**
Keep every tab (Overview, Leads, Projects/Builds, Services, Testimonials, Stats, Site Media & Video, Frame Sequences), every upload flow, every dedupe button, every progress line, same design tokens, same grid layout. No redesign work.

### STEP 3 — `README-security.md`
Copy-paste-friendly setup checklist:
1. Run `setup-security.sql` in Supabase → SQL Editor.
2. Create free Cloudflare Turnstile widget:
   - Go to `dash.cloudflare.com` → Turnstile → Add Widget
   - Name: anything; Widget type: Managed
   - Hostname: your live domain (e.g. `revnation.in`) AND `localhost` for testing
   - Copy the **Site Key** (public, starts with `0x`) — that's what goes in `config.js`
3. Update `config.js` with the Site Key.
4. Create your admin account:
   - Supabase → Authentication → Users → **Add User** → email + strong password. (You confirmed you're doing this.)
5. Register that user as an admin:
   - Supabase → Authentication → Users → click your user → copy the UUID
   - SQL Editor → run: `INSERT INTO admins (id) VALUES ('your-uuid-here');`
6. Optional dashboard hardening (all free, 2-minute toggles):
   - Auth → Providers → Email → **Disable "Allow new users to sign up"** — prevents attackers from self-creating free users to try login brute force
   - Auth → General → Enable "Confirm email" (only your signup email, since you won't allow public signups anymore)
7. Test: open `studio-gate-88.html` in incognito, type a wrong password 6 times → should lock + log in Audit tab.

### STEP 4 — `config.js` (1 new line)
Append `TURNSTILE_SITE_KEY:` with a clear comment showing the format. You paste yours.

### STEP 5 — `index.html` patch
Minimal surgical change in the `<form id="bookingForm">` block:
1. Add an invisible honeypot input (CSS `display:none`).
2. Add the Turnstile widget just above the submit button.
3. Update `submitLead()`:
   - If honeypot filled → silently return (bot).
   - If Turnstile not solved → don't submit, show "Please verify you're human."
   - Pass Turnstile token through; only call `db.from('leads').insert` when valid.
4. No redesign, no behavior change for real users.

### Verification checklist (I'll provide; YOU execute by testing)
Since I can't access your live Supabase project:
- Open `studio-gate-88.html`, try wrong password 6 times → locks after 5, shows countdown
- Look in Supabase → Table Editor → `login_attempts` → see your IP logged
- Delete a test project as admin → check `activity_log` has the entry
- Submit the booking form without CAPTCHA → is blocked
- Submit with CAPTCHA → appears in leads with timestamp + IP (in login_attempts, not leads directly — lead storage schema stays)

### Out of scope
- No changes to your live site's hero/scrolly-telling/cards — only the booking form block gets the security patch
- No changes to how Supabase Storage buckets work
- No monthly costs (everything is in the free tier)