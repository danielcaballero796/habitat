# Exploration: Device Dashboard UI for Habitat

**Change Candidate**: Smart home device dashboard (view/manage devices via web UI instead of curl)  
**Status**: EXPLORE phase  
**Created**: 2026-08-04  
**Context**: Rails 7.1 API-only app + single-user JWT auth + React knowledge unknown

---

## The Problem

Currently, you interact with Habitat only via the REST API (curl/Postman). To view your devices, manage them (rename, update status), or see device attributes (power consumption, voltage, etc.), you must manually craft HTTP requests.

A dashboard would provide:
- **List view**: See all devices at a glance
- **Detail view**: See device attributes and metadata
- **Quick actions**: Rename device, update status, add/remove attributes
- **Real-time feedback**: See changes reflected immediately

---

## The Fork: Three Architectural Paths

### Option A: Server-Rendered Rails Views (Full Stack Rails + Turbo/Hotwire)

**What it means**: Turn the existing API-only Rails app into a full Rails monolith. Add a view layer (ERB templates) with interactive features via Turbo/Hotwire (Rails' modern alternative to writing JavaScript).

**Tech Stack**:
- Keep `app/controllers/api/v1/*` unchanged (API endpoints)
- Add new `app/controllers/dashboards_controller.rb` (server-rendered HTML)
- Add `app/views/dashboards/*` (ERB templates)
- Add `app/javascript/controllers/*` (Stimulus.js for interactivity)
- Same database, same Rails server, same Docker container

**How it works**:
```
Browser --HTTP--> Rails Server
                     |
                     +-- API JSON (v1 endpoints) for external clients
                     +-- HTML views (dashboards) for web UI
                     
User clicks "Rename Device" in dashboard
  -> Form submission to Rails controller
  -> Controller calls internal User.find + Device.update
  -> Responds with Turbo stream (partial HTML replacement)
  -> Browser updates DOM without page reload
```

**Tradeoffs for Learning**:

✓ **Pros**:
- Single codebase, single deployment, single language (Ruby)
- You're already learning Rails; dashboards just add the "view" part you skipped in API-only mode
- Turbo is Rails-native and minimal JavaScript (stays in Rails ecosystem)
- Database is already there; no auth/API versioning complexity
- Fastest to "ship" a working dashboard (days, not weeks)
- Great for personal/hobby projects (you are the only user)

✗ **Cons**:
- Mixes API and web concerns in one codebase (harder to separate concerns as it grows)
- Session-based auth (currently you have JWT) — need to add `User.find_by(email/token)` to every view-based action OR implement Rails sessions alongside JWT
- No mobile app path (server-rendered HTML only works for web browsers)
- Turbo is opinionated; if you later want a separate frontend, you'd have to rip it out and rewrite

**Learning Value**: High. You'll see the full Rails stack (models → controllers → views) and understand why the API/view split exists.

---

### Option B: Pure API + Separate Frontend (API remains unchanged, new React/Vue SPA)

**What it means**: Keep the Rails app as pure API. Build a separate web frontend (React or Vue.js single-page app) that calls the API via HTTP. Frontend and backend are two independent codebases.

**Tech Stack**:
- Keep Rails `/v1/devices`, `/v1/login` unchanged
- New repository: `habitat-dashboard/` with React/Vue app
- Frontend calls `http://localhost:3000/v1/devices` via fetch/axios
- Two Docker services: `app` (Rails) + `dashboard` (Node.js dev server or static server)

**How it works**:
```
Browser --HTTP--> React Dashboard (static or Node dev server)
  |
  +---> Calls fetch('/v1/devices', { headers: Authorization: 'Bearer ...' })
        |
        +---> Rails API Server (unchanged)
              Returns JSON
```

**Tradeoffs for Learning**:

✓ **Pros**:
- Clean separation: API has one job (JSON), frontend has one job (UI)
- No mixing of concerns; each codebase is focused
- Transferable skills (React/Vue is valuable beyond this project)
- Mobile app path (same API can power native iOS/Android later)
- Scales intellectually (frontend dev ≠ backend dev; they can work independently)
- Production-grade separation (used by real SaaS companies)

✗ **Cons**:
- **Two codebases to maintain and deploy** (more operational complexity)
- **You must learn a frontend framework** (React/Vue) in addition to Rails — steep learning curve
- Token management in browser (JWT in localStorage or cookies — security/expiry considerations)
- CORS configuration required (Rails must allow requests from `localhost:3001`)
- Debugging across two servers (API errors, frontend errors, network issues)
- No built-in Rails form helpers; everything is manual (more code)
- Takes longer to ship (weeks, not days)

**Learning Value**: Very high, but only if you want to learn frontend frameworks. Otherwise, it's learning overload on top of Rails.

---

### Option C: Minimal Admin View (Rails Scaffold-Generated Views, No SPA)

**What it means**: Add Rails-generated HTML views (simpler than Turbo). Use Rails form helpers and page refreshes for simplicity. No Turbo, no Stimulus, no SPA complexity. Very traditional Rails.

**Tech Stack**:
- Keep API endpoints unchanged
- Add `app/controllers/admin/devices_controller.rb` (CRUD views)
- Add `app/views/admin/devices/` (ERB with `form_with`, `link_to`, etc.)
- Basic styling (Bootstrap CDN for quick UI)
- Full page refreshes on each action (no AJAX)

**How it works**:
```
Browser --HTTP GET--> Rails Server
                         |
                         +-- Render ERB template (HTML)
                         
User clicks "Rename", submits form
  --HTTP POST--> Rails Server
                    |
                    +-- Update device
                    +-- Redirect to device show page
                    +-- Full page load
```

**Tradeoffs for Learning**:

✓ **Pros**:
- Still single Rails codebase (no separate frontend repo)
- Uses Rails form helpers and conventions you're learning anyway
- Super simple, minimal JavaScript (maybe zero)
- Scaffold generator can auto-create CRUD views fast
- Teaches Rails the "classic way" (good for understanding fundamentals)
- Works fine for personal projects (no need for snappy UX)

✗ **Cons**:
- Full page refresh on every action (feels slow/old-fashioned; can be annoying)
- No interactivity without writing custom JavaScript
- Still a "separate concern" from the API (code duplication of auth logic)
- No frontend framework skills gained (pure Rails/HTML/CSS)
- Less applicable to modern web dev (though classics are good to know)

**Learning Value**: Medium. Good for Rails fundamentals, but doesn't teach modern frontend thinking.

---

## Decision Table: Tradeoffs at a Glance

| Factor | Option A (Turbo) | Option B (React/Vue) | Option C (Scaffold) |
|--------|------------------|----------------------|---------------------|
| **Codebase complexity** | 1 (single) | 2 (separate) | 1 (single) |
| **Time to working dashboard** | 1-2 days | 1-2 weeks | 1 day |
| **JavaScript needed?** | Minimal (Stimulus) | Yes (React/Vue) | No |
| **Rails learning curve** | Medium (adds views) | Medium (separate frontend) | Low (classic scaffold) |
| **Frontend learning** | Minimal | High (new framework) | None |
| **Mobile app path** | ✗ (web only) | ✓ (reuse API) | ✗ (web only) |
| **Production-grade?** | ✓ (modern Rails) | ✓ (industry standard) | Meh (classic, less modern) |
| **Best for hobby/personal?** | ✓ Ideal | Overkill | ✓ Ideal |
| **Best for learning full stack?** | ✓ Teaches Rails MVC | ✓ Teaches separation | ✓ Teaches Rails fundamentals |

---

## Key Questions for You (User)

Before we propose a concrete spec/design, answer these:

### 1. **What's your learning goal right now?**
   - A) Master Rails as a monolith (views + API in one app)?
   - B) Learn modern frontend frameworks (React/Vue) alongside Rails?
   - C) Get a working UI up ASAP without too much complexity?

### 2. **Do you see Habitat as:**
   - A) A personal hobby project (just for you, forever)?
   - B) Something that might grow into a real app (multi-user, mobile, etc.)?
   - C) A sandbox to learn both backend AND frontend?

### 3. **How much JavaScript/frontend experience do you have?**
   - A) None (never touched HTML/CSS/JS)?
   - B) A little (basic HTML/CSS, but no frameworks)?
   - C) Comfortable (could pick up React/Vue quickly)?

### 4. **What would "done" look like to you?**
   - A) A simple, working UI to see and rename my devices?
   - B) A polished dashboard that feels modern and responsive?
   - C) A production-grade system with unit tests, error handling, etc.?

---

## Current Project Context

**You have**:
- Rails 7.1 API-only app ✓
- Single-user JWT auth ✓
- Device model with EAV-lite attributes ✓
- Comprehensive REST endpoints ✓
- 88 passing tests ✓

**You're learning**:
- Rails fundamentals (models, controllers, migrations) ✓
- REST API design ✓
- Test-driven development (RSpec) ✓
- Docker + Rails deployment ✓

**You haven't touched yet**:
- Rails views (ERB, form helpers)
- Frontend frameworks (React/Vue)
- Turbo/Hotwire (modern Rails interactivity)
- Session-based auth (currently using JWT)

---

## Recommendation (Conditional on Answers)

**If learning goal is "master Rails as full-stack Ruby developer"**: 
→ **Option A (Turbo/Hotwire)** is your path. You'll learn the "Rails way" of building modern web apps without leaving Ruby.

**If learning goal is "get hired as a web developer (frontend + backend)"**: 
→ **Option B (React/Vue + API)** teaches you both worlds, but it's a 2-3x time investment.

**If you just want a working UI without complexity**: 
→ **Option C (Scaffold views)** gets you to a working dashboard in a day; you can always upgrade later.

**My teaching recommendation**: 
For a learning project, **Option A (Turbo)** is the sweet spot — you stay in Rails, learn the missing "view" piece, and ship fast. You can always separate it later if Habitat becomes something bigger.

---

## What Happens Next (After You Decide)

Once you pick an option, I'll run the full SDD cycle:

1. **PROPOSE**: Recommend specific feature set (e.g., "list devices, rename device, delete device")
2. **SPEC**: Write detailed scenarios (Given/When/Then) for each feature
3. **DESIGN**: Architecture (routes, controllers, components, auth flow)
4. **TASKS**: Break into 10-20 concrete implementation tasks
5. **APPLY**: Execute all tasks (write code, tests, etc.)
6. **VERIFY**: Run test suite, test manually in browser
7. **ARCHIVE**: Document the change, lessons learned

Each phase will have the same teaching walkthrough as device-foundation and api-foundation-with-auth.

---

## Questions for Clarification

1. **Do you want this dashboard public (anyone can see devices) or private (login required)?**
   - Likely: Private (login required; display current user's device list)

2. **Which device actions are most important?**
   - Must-have: View device list, view device details, rename device
   - Nice-to-have: Add device, delete device, manage attributes
   - Later: Automation, scheduling, real-time status updates

3. **How much styling/polish is enough?**
   - MVP: Bare-bones (readable, functional)
   - Nice: Bootstrap or Tailwind for decent look
   - Polished: Custom CSS, animations, responsive design

4. **Should the dashboard be the "landing page" (/) when you log in, or a separate route (/dashboard)?**
   - Current app has no landing page; might make sense to use dashboard as home

---

## Summary

You have three real architectural paths forward, each with tradeoffs. The choice depends on:
- **What you want to learn** (Rails views? Frontend frameworks? Both?)
- **What you want to build** (hobby project? Real app?)
- **How much time/complexity you're willing to invest** (1 day? 2 weeks?)

Pick your path → I'll propose concrete specs → We'll execute another full SDD cycle together.
