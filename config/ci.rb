# Run using bin/ci
# Local continuous integration: lint, security, and tests.
# No deployment steps. Prefer this over waiting on GitHub Actions when iterating.

CI.run do
  step "Setup", "bin/setup --skip-server"

  # Built CSS is gitignored; request specs render the layout that links tailwind.css.
  step "Assets: Tailwind", "bin/rails tailwindcss:build"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --confidence-level=2 --exit-on-warn --exit-on-error"

  step "Tests: RSpec", "bin/test-parallel"
end
