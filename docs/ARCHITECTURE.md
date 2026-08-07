# Architecture

## Overview

Git Team Reporting is a local Rails 8 monolith:

- **Browser UI** for CRUD and report generation
- **PostgreSQL** for teams, members, repositories, and archived reports
- **Octokit** for GitHub REST API access
- **Rails session** for optional PAT / endpoint / owner overrides (not durable app state)

There is no multi-user auth for the Rails app itself in the MVP (local single-operator use).

## Data model

```
Team
  has_many TeamMembers
  has_many Repositories
  has_many Reports (optional FK; nullified on team delete)

TeamMember
  belongs_to Team
  name, email, github_username (normalized)

Repository
  belongs_to Team
  owner, name  (unique pair)
  full_name => "owner/name"

Report  (archived generation result)
  optional belongs_to Repository, Team
  repository_full_name, team_name   (denormalized snapshots)
  start_date, end_date, date_range_label, preset
  format, filename, content
  metrics_payload (jsonb)
  generated_at
```

Migrations live under `db/migrate/`.

## Request flow: generate report

```
POST /reports
  ReportsController#create
    resolve Repository (+ team members)
    Reports::DateRange.resolve(preset / custom)
    Github::ConfigResolver (session + ENV)
    Reports::Generator
      Github::ClientFactory → Octokit::Client
      Github::ActivityFetcher
        GET repo, commits, PRs, reviews, issues
      MetricsAggregator + DeveloperMatcher
    Reports::Archiver
      HtmlRenderer | CsvRenderer | MarkdownRenderer | PdfRenderer
      Report.create! (metadata + content bytea + metrics_payload)
    redirect_to /reports/:id
```

Errors (missing token, bad dates, API 404/401, DNS/connection) are rescued and shown as flash alerts on the generate form when possible.

## Services

### `Github::`

| Class | Responsibility |
|-------|----------------|
| `ConfigResolver` | Resolve API endpoint, default owner, token from session then ENV |
| `TokenResolver` | Token-only facade over `ConfigResolver` |
| `ClientFactory` | Build Octokit client (`access_token`, `api_endpoint`, auto_paginate) |
| `ActivityFetcher` | Fetch and normalize activity in a date range; map Octokit/Faraday errors |
| `Error` hierarchy | `NotFoundError`, `UnauthorizedError`, `RateLimitError`, `ApiError`, … |

### `Reports::`

| Class | Responsibility |
|-------|----------------|
| `DateRange` | Presets: this/last week/month; custom ISO dates |
| `DeveloperMatcher` | Match login/email → `TeamMember` |
| `MetricsAggregator` | Per-developer and team/repo totals |
| `Generator` | Orchestrate fetch + aggregate |
| `HtmlRenderer` | Render archival HTML (`layouts/report_export`) |
| `CsvRenderer` | Render UTF-8 CSV from metrics payload |
| `MarkdownRenderer` | Render GFM Markdown from metrics payload |
| `PdfRenderer` | Render multi-page PDF via Prawn |
| `ExportData` | Shared column/header normalization for exporters |
| `Archiver` | Persist `Report` row + file body (`content` is `bytea`) |

## Configuration

`config/initializers/github.rb`:

- `config.x.github.api_endpoint` — from `GITHUB_API_ENDPOINT` (default `https://api.github.com`)
- `config.x.github.default_owner` — from `GITHUB_DEFAULT_OWNER` (default blank)
- `config.x.github.token_env_keys` — `GITHUB_TOKEN`, `GITHUB_ENTERPRISE_TOKEN`
- Session keys: `:github_pat`, `:github_api_endpoint`, `:github_default_owner`

`Github::ConfigResolver` normalizes `https://github.com` → `https://api.github.com` and trims trailing slashes.

## Security

| Concern | Approach |
|---------|----------|
| PAT storage | ENV and/or session only; never DB or files |
| Log redaction | `filter_parameter_logging` includes `token`, `github_pat`, `pat`, `access_token` |
| App auth | None (local trust model) |
| CSRF | Standard Rails protect_from_forgery |
| Host auth | Test disables host check; production should configure `config.hosts` as needed |

Do not commit `.env` or real tokens. Rotate tokens if exposed.

For the public trust model and vulnerability reporting, see [SECURITY.md](../SECURITY.md).

## UI

- Layout: `app/views/layouts/application.html.erb` (Tailwind + shared CSS components)
- Report archive HTML: `report_export` layout + `reports/archived` template
- Report show embeds archived HTML in an iframe (`srcdoc`) for isolation

## Testing

| Layer | Location |
|-------|----------|
| Models | `spec/models/*` |
| Requests | `spec/requests/*` |
| Services | `spec/services/**/*` |
| Factories | `spec/factories/*` |
| WebMock | `spec/support/webmock.rb` — network disabled except localhost |

`spec/rails_helper.rb` forces `RAILS_ENV=test` because the devcontainer defaults to `development`.

## Report formats

`Reports::Archiver#render_content` dispatches on `Report::FORMATS`:

| Format | Renderer | Notes |
|--------|----------|--------|
| `html` | `HtmlRenderer` | Self-contained HTML archive; show page uses iframe `srcdoc` |
| `csv` | `CsvRenderer` | UTF-8 text (no Excel BOM); metadata + developer rows |
| `markdown` | `MarkdownRenderer` | Portable GFM tables |
| `pdf` | `PdfRenderer` | Prawn + prawn-table; binary body |

`reports.content` is PostgreSQL **`bytea`** so PDF binary is safe. Text formats are stored as UTF-8 bytes; `Report#content_for_display` force-encodes for HTML/CSV/Markdown previews.

## Later improvements (out of scope)

- Reduce per-commit stats API calls (batching / optional toggle)
- Optional multi-user app authentication
- Persisted report search/filter beyond chronological list
- Re-export an existing report as another format without re-fetching GitHub

## Related routes

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/` | Dashboard |
| CRUD | `/teams`, `/teams/:id/members/*` | Teams & members |
| CRUD | `/repositories` | Repos |
| GET/PATCH/DELETE | `/settings` | Session config |
| GET | `/reports` | History |
| GET | `/reports/new` | Generate form |
| POST | `/reports` | Generate + archive |
| GET | `/reports/:id` | View archive |
| GET | `/reports/:id/download` | Download file |
| DELETE | `/reports/:id` | Delete archive |
| GET | `/up` | Health |
