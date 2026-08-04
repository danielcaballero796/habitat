# CLAUDE.md — Habitat

Project-scoped instructions for Claude Code sessions working in **this**
repository. This file is about Habitat's own code conventions; it does not
duplicate memory-system, RTK, or agent-orchestration rules from the user's
global `~/.claude/CLAUDE.md` — those still apply, just aren't repeated here.

## Project summary

Habitat is a Rails 7.1 (`config.api_only = true`) smart-home device
management app: a JWT-authenticated JSON API under `/v1/*` for programmatic
access, and a session-authenticated server-rendered HTML dashboard under
`/dashboard/*` using Turbo Streams + Stimulus for modal-based CRUD. It's a
personal learning project built with a written SDD (Spec-Driven Development)
workflow — see `README.md` for the full architecture writeup, ER diagram,
and request-flow diagram before making structural changes.

## Key architectural decisions (see README.md for diagrams)

- **`config.api_only = true` with manually restored middleware**
  (`config/application.rb`): the app started as API-only, then had cookies
  + session store, `ActionDispatch::Flash`, and `Rack::MethodOverride` added
  back by hand once the dashboard needed them. Each addition has an inline
  comment explaining the specific bug it fixes (empty flash → `NoMethodError`;
  missing `MethodOverride` → silent 404 on every edit/delete form). Read
  those comments before touching that file — see the "Architecture overview"
  section of `README.md` for the full explanation.
- **Two independent auth systems, do not cross them**: `Authenticable`
  (`app/concerns/authenticable.rb`) + `JwtService` (`lib/jwt_service.rb`)
  protect `/v1/*` only. `SessionsHelper#require_login`
  (`app/helpers/sessions_helper.rb`) protects `/dashboard/*` only. Never add
  `require_login` to a `V1::*` controller or JWT checks to a `Dashboard::*`
  controller — see the README's dual-auth flow diagram.
- **Turbo Streams + Stimulus for the dashboard, not full page reloads**:
  `Dashboard::DevicesController` / `Dashboard::DeviceAttributesController`
  `create`/`update`/`destroy` render arrays of `turbo_stream` actions
  (including the custom `close_modal` action registered in
  `app/javascript/controllers/turbo_stream_actions.js`). Modal open/close,
  focus trap, and delete-confirmation dialogs are Stimulus controllers under
  `app/javascript/controllers/` — read the comment header of each one before
  adding a new modal, they explain non-obvious things (why `modal-trigger`
  needs an outlet instead of a plain `data-action`, why forms must re-render
  with `status: :unprocessable_entity` and not a bare 200 for Turbo Drive to
  actually show validation errors).

## Testing conventions

- Framework: RSpec + FactoryBot. Request/controller specs describe behavior
  by hitting routes and asserting on `response`; system specs
  (`spec/system/dashboard/`) drive a real headless Chrome via Capybara +
  Cuprite for anything that depends on JS (modals, Turbo Streams, focus
  trapping).
- Run everything inside the Docker container, against the same Postgres
  used for dev:
  ```bash
  docker compose exec app bundle exec rspec
  docker compose exec app bundle exec rspec spec/models/device_spec.rb
  docker compose exec app bundle exec rspec spec/system/dashboard/devices/create_spec.rb
  ```
- `spec/rails_helper.rb` disables Rails' transactional-fixtures wrapper
  (`use_transactional_fixtures = false`) and delegates all cleanup to
  `DatabaseCleaner`: transaction strategy for normal specs, **truncation**
  for `type: :system` specs specifically, because system specs run the app
  on a separate Puma thread with its own DB connection that can't see the
  test thread's open transaction. If you add a new system spec and see
  `"... has already been taken"` on the second example, this is the
  mechanism to check first, not a factory bug.
- New controller actions that render forms on validation failure must use
  `status: :unprocessable_entity` (never a bare `200`) — Turbo Drive only
  replaces the page body in place on a redirect or non-2xx response; a
  silent 200 re-render is ignored client-side. Every existing dashboard
  controller already follows this; match the pattern.

## Known issues

- **`403 Blocked hosts: www.example.com` in dashboard request specs**:
  `spec/requests/dashboard_spec.rb` and every spec under
  `spec/requests/dashboard/` currently fail with this error. It is an
  `ActionDispatch::HostAuthorization` / test-environment host allowlist
  issue — Rails request specs default to `www.example.com` as the request
  host, and nothing in `config/environments/test.rb` currently permits it
  (only `config/environments/production.rb` even mentions `config.hosts`,
  commented out). **This is pre-existing and unrelated to app logic** — if
  you're working on the dashboard and these specs fail, that is expected
  going in, not something you broke. Do not "fix" it by weakening
  controller logic. The system specs under `spec/system/dashboard/` are
  unaffected (Capybara/Cuprite don't go through the same host-check path)
  and are the more reliable signal for dashboard behavior in the meantime.
- The dashboard's `flash` Stimulus auto-dismiss controller
  (`app/javascript/controllers/flash_controller.js`) has no JS-driver
  coverage in request specs by design — verify flash auto-dismiss timing
  manually in the browser or via a system spec if you touch it.

## Git / PR workflow notes specific to this repo

- Branch naming actually used in this repo's history: `feature/<slug>`,
  `fix/<slug>`, `chore/<slug>`, `docs/<slug>` (e.g.
  `feature/device-dashboard`, `fix/dashboard-flash-middleware`,
  `chore/sdd-archive-device-dashboard`). Follow this pattern rather than
  inventing a new prefix.
- Commit style is Conventional Commits, often scoped:
  `feat(dashboard): ...`, `fix(dashboard): ...`, `test(dashboard): ...`,
  `docs: ...`, `sdd: ...`. Check `git log --oneline` for the current
  pattern before writing a commit message.
- CI (`.github/workflows/ci.yml`) triggers on push/PR to `master` (note:
  not `main` — the workflow file still targets `master` even though the
  default branch used in practice is `main`; verify which branch actually
  triggers CI before assuming a PR will run it), spins up Postgres 16 as a
  service container, runs `bundle exec rails db:test:prepare` then
  `bundle exec rspec`.
- SDD artifacts (`design*.md`, `tasks-*.md`, `ARCHIVE-*.md`) live at the
  repo root, not in a `openspec/` directory. When starting a new SDD change
  in this repo, follow that existing flat-file convention rather than
  introducing a new directory structure.
