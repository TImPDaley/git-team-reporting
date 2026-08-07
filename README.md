# Git Team Reporting

Local **Ruby on Rails 8** app that generates **developer activity reports** from **GitHub Enterprise** (or github.com) repositories.

## What it does

1. You define **teams** and **team members** (name, email, optional GitHub username).
2. You associate each **repository** with one team.
3. You **generate a report** for a repo and date range.
4. The app calls the GitHub REST API, aggregates metrics, matches contributors to members, and **saves** an HTML report you can reopen later without re-fetching.

**Local-only, single-operator.** There is **no multi-user login** for the Rails app. Treat the machine (and browser session) as trusted. Personal access tokens are never stored in the database (ENV and/or encrypted browser session cookie only). Do not expose this app on a public URL without adding authentication first.

## Stack

| Layer | Choice |
|--------|--------|
| Runtime | Ruby 3.4.9, Rails 8.1.x |
| Database | PostgreSQL 16 |
| UI | Tailwind CSS 4, Hotwire (Turbo/Stimulus), importmap |
| GitHub | [Octokit](https://github.com/octokit/octokit.rb) REST client |
| Jobs / cache / cable | Solid Queue, Solid Cache, Solid Cable |
| Tests | RSpec, FactoryBot, WebMock, Shoulda, SimpleCov |
| Quality | RuboCop (Omakase), Brakeman, bundler-audit |

## Features (MVP)

| Area | Details |
|------|---------|
| **Teams** | CRUD; members nested under each team |
| **Team members** | Name, email, GitHub username; normalized for matching |
| **Repositories** | Owner/org + name; **one team per repo** |
| **Generate report** | Saved repo or manual entry; date presets or custom range |
| **GitHub fetch** | Commits, pull requests, reviews, issues (paginated via Octokit) |
| **Matching** | By GitHub username, then email; unmatched section |
| **Metrics** | Commits, PR open/merge/closed-unmerged, reviews, issues, lines ±, avg PR cycle time, author vs committer |
| **Report history** | Stored with run date, date range, repo name, team name, format, file content |
| **Settings** | Session overrides for API endpoint, default owner/org, PAT |
| **Formats** | **HTML**, **CSV**, **Markdown**, and **PDF** archived and downloadable |

## Quick start (Dev Container)

1. Open this folder in VS Code / Cursor.
2. **Reopen in Container** (Dev Containers extension).
3. After `post-create` finishes:

```bash
bin/rails db:prepare
bin/rails tailwindcss:build
bin/dev
# or:
bin/rails server -b 0.0.0.0 -p 3000
```

4. Open [http://localhost:3000](http://localhost:3000).

Dev container includes local PostgreSQL, Chromium (system tests), GitHub CLI (`gh`), and Grok Build mounts.

### Configuration

Copy `env.example` to `.env` (gitignored) if you want env-based defaults:

| Variable | Default | Purpose |
|----------|---------|---------|
| `GITHUB_API_ENDPOINT` | `https://api.github.com` | REST API **base** URL |
| `GITHUB_DEFAULT_OWNER` | _(blank)_ | Default org/owner in forms (optional) |
| `GITHUB_TOKEN` or `GITHUB_ENTERPRISE_TOKEN` | _(none)_ | Personal access token |

**Or** use **Settings** in the UI for session-only overrides (endpoint, owner, token). Prefer ENV for day-to-day tokens; session is fine for temporary testing.

#### API endpoint (important)

| Target | Correct API endpoint | Wrong |
|--------|----------------------|--------|
| github.com | `https://api.github.com` | `https://github.com`, repo web URLs |
| GitHub Enterprise Server | `https://<host>/api/v3` | Host without `/api/v3`, repo pages |

The Generate Report page shows the **active** endpoint and whether it comes from `env` or `session`. The app default is github.com (`https://api.github.com`). For GitHub Enterprise Server, set `GITHUB_API_ENDPOINT` or Settings to `https://<host>/api/v3`.

## User guide

### 1. Settings

- Confirm **API endpoint** and **default owner**.
- Provide a PAT (ENV or session). Token needs read access to the target repos (classic `repo` / public_repo, or fine-grained Contents + Metadata as needed).

### 2. Teams & members

- **Teams** → create a team.
- Add members with **email** and **GitHub username** when known (used for matching).

### 3. Repositories

- **Repositories** → create `owner/name` and select the team.

### 4. Generate

- **Generate** → pick a saved repository (or enter owner/name + team).
- Choose date range: this week, last week, this month, last month, or custom.
- Format: HTML (MVP).
- Submit → report is generated **and saved**.

### 5. Reports history

- **Reports** lists past runs: run date, repo, team, date range, format.
- **View** reopens stored content (no new GitHub call).
- **Download** exports the stored file.
- **Delete** removes the archive.

## Architecture

```
Browser UI
    │
    ├─ Teams / Members / Repositories  →  PostgreSQL
    ├─ Settings (session overrides)    →  Rails session only
    └─ Generate Report
            │
            ▼
    Reports::Generator
            │
            ├─ Github::ConfigResolver   (ENV + session)
            ├─ Github::ClientFactory    (Octokit)
            ├─ Github::ActivityFetcher  (commits, PRs, reviews, issues)
            ├─ Reports::DeveloperMatcher
            ├─ Reports::MetricsAggregator
            └─ Reports::Archiver        → Report row + HTML content
```

Key paths:

| Path | Role |
|------|------|
| `app/models/` | `Team`, `TeamMember`, `Repository`, `Report` |
| `app/services/github/` | API client, config, activity fetch |
| `app/services/reports/` | Date range, matching, metrics, HTML, archive |
| `app/controllers/` | CRUD + generate/show/download |
| `config/initializers/github.rb` | Defaults and session key names |
| `spec/` | Model, request, and service specs (WebMock) |

## Commands

```bash
bin/setup --skip-server          # gems + db:prepare
bin/dev                          # Puma on 0.0.0.0:3000 + Tailwind watch
bin/rails server -b 0.0.0.0 -p 3000
bin/rails tailwindcss:build      # one-shot CSS
bin/rails console
bundle exec rspec                # full suite
bin/test-parallel                # parallel non-system + sequential system
bin/ci                           # setup, rubocop, security, tests
bin/check-coverage               # coverage threshold after tests
bundle exec rubocop
```

Health check: `GET /up`.

## Testing

```bash
bundle exec rspec
```

- **No live GitHub calls** — HTTP is stubbed with WebMock.
- Coverage via SimpleCov; see `bin/check-coverage` for thresholds.
- Devcontainer sets `RAILS_ENV=development`; `spec/rails_helper.rb` **forces** `RAILS_ENV=test` so specs do not run against the development DB/CSRF settings.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Browser spins / never loads | Server bound only to localhost; port forward | Use `bin/dev` (binds `0.0.0.0`) or `bin/rails server -b 0.0.0.0` |
| Many browser tabs open | Port auto-forward = “Open Browser” | Ports panel → 3000 → **Silent**; repo sets silent in `.devcontainer` / `.vscode` |
| `Faraday::ConnectionFailed` / DNS errors | Wrong or unreachable API host | Confirm Settings / `GITHUB_API_ENDPOINT` (`https://api.github.com` or reachable GHE `/api/v3`) |
| Repo not found | Wrong host, token, or private-repo 404 | Check endpoint, PAT scopes, owner/name |
| Report expired (old behavior) | Pre-persist cache-only reports | Use current app: reports are stored in DB |

## Documentation

| Doc | Description |
|-----|-------------|
| [README.md](README.md) | This file — overview, setup, usage |
| [docs/USER_GUIDE.md](docs/USER_GUIDE.md) | Step-by-step UI walkthrough |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Services, data model, security notes |
| [SECURITY.md](SECURITY.md) | Trust model, secret handling, vulnerability reporting |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Setup, tests, pull request expectations |
| [env.example](env.example) | Environment variable template |

## CI

GitHub Actions: [`.github/workflows/ci.yml`](.github/workflows/ci.yml)  
Local: `bin/ci`.

## Security

This app is intended for **local use by one operator**, not as a multi-tenant internet service.

| Topic | Guidance |
|--------|----------|
| **App auth** | None in the MVP. Anyone who can reach the UI can manage teams/repos and trigger reports. |
| **GitHub PATs** | Supply via `GITHUB_TOKEN` / `GITHUB_ENTERPRISE_TOKEN` in `.env` (gitignored) or temporary **Settings** session override. Never commit real tokens. |
| **Session** | Session may hold a PAT override; protect the browser/session on shared machines. |
| **Logs** | Sensitive parameter names (`token`, `github_pat`, `pat`, `access_token`) are filtered from logs. |
| **Secrets files** | Do not commit `.env` or `config/master.key`. `config/credentials.yml.enc` is encrypted Rails credentials; keep the master key private. |
| **Deploying** | If you ever host beyond localhost, add real authentication, configure `config.hosts` / TLS, and set `SECRET_KEY_BASE` via environment—do not use the default local trust model. |

See **[SECURITY.md](SECURITY.md)** for the full trust model and how to report vulnerabilities privately.

## Contributing

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for setup, `bin/ci`, and pull request expectations.

## License

This project is licensed under the [MIT License](LICENSE).
