# User guide

This guide walks through day-to-day use of **Git Team Reporting** in the browser.

Base URL (local): [http://localhost:3000](http://localhost:3000)

## Prerequisites

1. App running (`bin/dev` or `bin/rails server -b 0.0.0.0 -p 3000`).
2. Database prepared (`bin/rails db:prepare`).
3. A GitHub personal access token with read access to the repositories you report on.
4. Correct **API endpoint** for your host (see below).

## Configure connection (Settings)

Open **Settings** in the nav.

### Active values

The top card shows what the app will use right now:

- **API endpoint** (source: `env` or `session`)
- **Default owner / org**
- **Token** (present/missing and source)

### Session connection overrides

Use these for temporary overrides without editing `.env`:

1. **API endpoint** — REST base URL only.
   - github.com → `https://api.github.com`
   - GitHub Enterprise Server → `https://your-hostname/api/v3`
2. **Default owner / org** — optional prefill on forms (e.g. your org login). Leave blank to require entering owner on each form.
3. Click **Save connection overrides**.

Setting a field equal to the environment default (or clearing default owner) removes that session override.

### Session token override

1. Paste a PAT (shown as a password field).
2. **Save token override**.

Blank token field means “leave the current token alone.”

**Clear all session overrides** removes endpoint, owner, and token from the browser session.

### Security notes

- Session values live in the **encrypted Rails session cookie**, not the database.
- Prefer `GITHUB_TOKEN` in the environment for a durable local setup.
- Never commit tokens. Rotate a token if it appears in logs or chat.

## Manage teams

1. Open **Teams** → **New team**.
2. Enter name and optional description → save.
3. On the team page, **Add member**:
   - **Name** — display name
   - **Email** — used for matching commit authors
   - **GitHub username** — optional but recommended; leading `@` is stripped
4. Edit or remove members as needed.

Deleting a team is blocked while repositories still reference it.

## Manage repositories

1. Open **Repositories** → **New repository**.
2. Set **owner/org**, **repository name**, and **team**.
3. Save.

Each repository has exactly one team. The report uses that team’s members for matching.

## Generate a report

1. Open **Generate**.
2. Confirm **Active API endpoint** at the top of the form (must match your host).
3. Choose a **saved repository**, or enter owner, name, and team manually.
4. Choose a **date range**:
   - This week / last week / this month / last month, or
   - Custom start and end dates
5. Choose an **output format**:
   - **HTML** — interactive archive preview in the browser (default)
   - **CSV** — spreadsheet-friendly export
   - **Markdown** — portable document for docs/PRs
   - **PDF** — printable leadership-friendly file
6. Click **Generate & save report**.

The app will:

1. Authenticate with your token.
2. Fetch activity from GitHub for that repo and range.
3. Match contributors to team members.
4. Save a **Report** record (metadata + file content for the chosen format).
5. Redirect to the saved report page (preview for HTML/CSV/Markdown; download for PDF).

### Metrics included

Per developer (and team/repo totals):

- Commits; lines added/deleted (when available)
- PRs opened, merged, closed without merge
- Reviews submitted
- Issues created/closed (non-PR issues)
- Average PR cycle time (hours, open → merge)
- Commits as author vs non-author committer counts

Unmatched GitHub identities appear in an **Unmatched contributors** section.

## Report history

Open **Reports**.

| Column | Meaning |
|--------|---------|
| Run date | When generation finished |
| Repository | Snapshot of `owner/name` |
| Team | Snapshot of team name |
| Date range | Report period |
| Format | HTML, CSV, Markdown, or PDF |

Actions:

- **View** — open archived content (no new API call)
- **Download** — download the stored file
- **Delete** — remove the archive

Repo or team records can later be deleted; historical reports keep their denormalized names.

## Home dashboard

Shows counts for teams, members, repositories, and saved reports, plus recent reports and token status.

## Common workflows

### First-time github.com testing

1. Confirm API endpoint is `https://api.github.com` (app default)
2. Optionally set default owner to your org or user login (or leave blank)
3. Settings → session PAT (or set `GITHUB_TOKEN`)
4. Create team + members with GitHub usernames
5. Create repository `YourOrg/your-repo`
6. Generate for last week / last month
7. Open **Reports** to confirm it was saved

### GitHub Enterprise Server

1. Settings → API endpoint `https://your-hostname/api/v3` (must be reachable from your machine), or set `GITHUB_API_ENDPOINT`
2. Optionally set default owner to your org on that host
3. PAT issued by that GHE instance
4. Generate as above

## FAQ

**Why do I get DNS / Faraday errors for a GHE host?**  
The host is unreachable from your network, or the endpoint is wrong. For github.com use `https://api.github.com` (the app default). For GHE, use `https://<host>/api/v3` only when that host is reachable.

**Why is the repo “not found”?**  
Wrong API host, insufficient token scopes, private repo without access, or incorrect owner/name. Private repos often return 404 instead of 403 when unauthorized.

**Do I need to re-run a report to view it later?**  
No. Saved reports under **Reports** include the file content.

**Are tokens stored in PostgreSQL?**  
No.
