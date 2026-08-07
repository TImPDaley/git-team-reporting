# Contributing

Thanks for your interest in Git Team Reporting.

## Development setup

**Recommended:** open the repo in VS Code / Cursor and **Reopen in Container** (Dev Containers). Then:

```bash
bin/rails db:prepare
bin/rails tailwindcss:build
bin/dev
```

App: [http://localhost:3000](http://localhost:3000).

**Without Dev Container:** Ruby 3.4.9, PostgreSQL 16, and the usual Rails toolchain. Copy `env.example` → `.env` if you want env defaults (never commit real tokens).

## What to run before a PR

```bash
bin/ci
```

That path is what GitHub Actions exercises (setup, RuboCop, Brakeman, bundler-audit, RSpec). You can also run pieces:

```bash
bundle exec rubocop
bundle exec brakeman --no-pager --confidence-level=2
bin/bundler-audit
bundle exec rspec
```

Notes:

- Specs **must not** call live GitHub — HTTP is stubbed with WebMock.
- `spec/rails_helper.rb` forces `RAILS_ENV=test` even if the container defaults to development.

## Pull requests

1. Fork (or branch) from `main`.
2. Keep changes focused — one concern per PR when practical.
3. Add or update RSpec coverage for behavior changes.
4. Update `README.md` / `docs/` when user-facing behavior or setup changes.
5. Do not commit secrets, `.env`, or `config/master.key`.

## Reporting bugs and ideas

- **Security:** see [SECURITY.md](SECURITY.md) (private report, not a public issue with exploit details).
- **Bugs / features:** open a GitHub issue with reproduction steps, expected vs actual behavior, and your Ruby/Rails version when relevant.

## Code style

- Ruby: RuboCop Omakase (`bundle exec rubocop`)
- Prefer small service objects under `app/services/` for GitHub and report generation (see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md))

## License

By contributing, you agree that your contributions are licensed under the same [MIT License](LICENSE) that covers this project.
