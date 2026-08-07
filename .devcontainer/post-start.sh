#!/bin/bash
set -e

# Log to file for debugging
LOGFILE="/tmp/post-start.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "🚀 Running post-start setup... ($(date))"

# Grok Build: directory-mounted GROK_HOME + PATH for this shell and child processes.
# Binary/auth/sessions live on the host under ~/.grok-devcontainer and survive rebuilds.
GROK_HOME="${GROK_HOME:-$HOME/.grok}"
export GROK_HOME
if [ -x "$GROK_HOME/bin/grok" ]; then
  export PATH="$GROK_HOME/bin:$PATH"
  echo "✅ Grok on PATH ($("$GROK_HOME/bin/grok" --version 2>/dev/null || echo "$GROK_HOME/bin/grok"))"
elif [ -d "$GROK_HOME" ]; then
  echo "⚠️  Grok not installed yet under $GROK_HOME — run post-create or:"
  echo "     curl -fsSL https://x.ai/cli/install.sh | bash"
else
  echo "⚠️  GROK_HOME missing ($GROK_HOME). Rebuild so initializeCommand creates ~/.grok-devcontainer."
fi

# Start PostgreSQL and wait for it to be ready
if ! sudo -u postgres pg_isready > /dev/null 2>&1; then
  echo "📦 Starting PostgreSQL..."
  sudo service postgresql start
  
  echo "⏳ Waiting for PostgreSQL to be ready..."
  until sudo -u postgres pg_isready; do
    sleep 1
  done
  echo "✅ PostgreSQL is ready"
else
  echo "✅ PostgreSQL is already running"
fi

# Start the postgres watchdog in the background
echo "🐕 Starting PostgreSQL watchdog..."
nohup /usr/local/bin/postgres-watchdog > /tmp/postgres-watchdog.log 2>&1 &
echo "✅ Watchdog started"

# Navigate to Rails app directory
cd "${CONTAINER_WORKSPACE_FOLDER:-/workspaces/git-team-reporting}"

# Ruby LSP uses a composed Gemfile under .ruby-lsp/ only when ruby-lsp is NOT in the
# project Gemfile. If both exist, eval_gemfile + duplicate gem lines make Bundler fail.
if [ -f .ruby-lsp/Gemfile ] && ! grep -qE 'gem ["'\'']ruby-lsp["'\'']' Gemfile; then
  if ! BUNDLE_GEMFILE=.ruby-lsp/Gemfile bundle check >/dev/null 2>&1; then
    echo "💎 Updating Ruby LSP bundle..."
    BUNDLE_GEMFILE=.ruby-lsp/Gemfile bundle install
    echo "✅ Ruby LSP bundle ready"
  fi
elif grep -qE 'gem ["'\'']ruby-lsp["'\'']' Gemfile; then
  echo "✅ Ruby LSP provided by main Gemfile (skipping .ruby-lsp composed bundle)"
fi

# Prepare databases (idempotent - safe to run multiple times)
echo "🗄️  Preparing databases..."
bin/rails db:prepare 2>&1 | grep -v "already exists" || true
RAILS_ENV=test bin/rails db:prepare 2>&1 | grep -v "already exists" || true
echo "✅ Databases ready"

echo "🎉 Post-start setup complete! ($(date))"
echo "📝 Log saved to: $LOGFILE"
