# Git Team Reporting — Agent Guidelines

## Project Overview

Local Ruby on Rails app that generates developer activity reports from GitHub Enterprise (or github.com) repositories.

**Technology stack:**

- **Ruby**: 3.4.9
- **Rails**: ~> 8.1.4
- **Database**: PostgreSQL 16
- **UI**: Tailwind CSS 4, Hotwire (Turbo/Stimulus), import maps
- **GitHub client**: Octokit
- **Jobs / cache / cable**: Solid Queue, Solid Cache, Solid Cable
- **Hosting**: local-only. There is no Heroku deploy workflow. Do not expose this app on a public URL without adding authentication first.
- **Testing**: RSpec, FactoryBot, WebMock, Shoulda, SimpleCov
- **Code quality**: RuboCop (Rails Omakase), Brakeman, bundler-audit, gitleaks in CI

Specs **must not** call live GitHub — HTTP is stubbed with WebMock.

This is the public, current Git Team Reporting repo. The older private sibling `TImPDaley/git_team_reporting` is out of scope for this standard.

For setup and usage, see [README.md](README.md), [CONTRIBUTING.md](CONTRIBUTING.md), and `docs/`.

## Git and PR workflow

These rules apply to every coding agent working in this repository.

- Never commit or push unless the user explicitly asks. One approval does not cover later commits.
- Work on a non-default branch (this repo's default branch is `main`).
- Before suggesting a commit: run `git status` and `git diff`, stage only files for this task, and give the user exact git commands plus a lowercase, action-oriented commit message.
- Do not add `Co-authored-by` trailers for any agent or tool.
- Before using `gh`, run `unset GITHUB_TOKEN GH_TOKEN`.
- Merges are squash-only. Do not rebase shared branches or force-push (including the default branch) without explicit confirmation.
- Link issues with `Refs #N` unless the user wants the issue closed, in which case `Fixes #N` is allowed. Never use closing keywords on tracking issues that must stay open.
- Open a PR and wait for CI to go green. The **CODE REVIEW** bot reviews a PR only when Tim or his Chief of Staff asks; address its comments, then Tim reviews. Do not request GitHub Copilot as a reviewer, and do not treat Copilot review comments as a required step.
- Do not merge until Tim explicitly says to merge.
- After merge, there is no production deploy. This is a local-only app. Report that no deploy ran.

## Testing and CI

Before suggesting a commit or claiming work is done:

```bash
bin/ci
bin/check-coverage
```

`bin/ci` (`config/ci.rb`) runs setup, the Tailwind build, RuboCop, bundler-audit, importmap audit, Brakeman (`--confidence-level=2 --exit-on-warn --exit-on-error`), and `bin/test-parallel`. The CI **test** job runs RuboCop, Brakeman (`--confidence-level=2`), bundler-audit, parallel non-system specs, system specs, and `bin/check-coverage`; it does not run the importmap audit. CI also runs **Secret scan (gitleaks)**. Neither gitleaks nor `bin/check-coverage` is part of `bin/ci`, which is why `bin/check-coverage` is listed separately above.

CI jobs on each PR: **Secret scan (gitleaks)** and **test**. Both must be green.

## Dev Container and Grok Build

The preferred work environment is the Dev Container. Run Grok from the integrated terminal inside the container, not from the host, when making code changes.

- Persist Grok state by bind-mounting host `~/.grok-devcontainer` to `/home/vscode/.grok` and setting `GROK_HOME`. Persist `gh` auth with `~/.config/gh`.
- Do not install the `GitHub.copilot` VS Code extension in `.devcontainer/devcontainer.json`.
- Do not request GitHub Copilot as a pull-request reviewer.
- Verify with this repo's test and lint commands before claiming work is done or suggesting a commit.

This repo already uses the HUFC-style Dev Container with Grok and `gh` bind mounts. The `GitHub.copilot` extension must stay out of `devcontainer.json`.

## Code style and structure

- Follow RuboCop Rails Omakase (`.rubocop.yml`).
- Prefer small service objects under `app/services/` for GitHub and report generation (see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)).
- Never store personal access tokens in the database.
