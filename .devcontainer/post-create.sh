#!/bin/bash
set -e

# Log to file for debugging
LOGFILE="/tmp/post-create.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "🔨 Running post-create setup... ($(date))"

# Configure Git settings
echo "⚙️  Configuring Git..."
git config --global push.autoSetupRemote true

# Set (or remind about) git user identity so commits have your name/email
if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
  echo "⚠️  Git user.name / user.email not set yet."
  echo "   To set your identity inside the container, run:"
  echo "     git config --global user.name \"Your Full Name\""
  echo "     git config --global user.email \"you@users.noreply.github.com\""
  echo "   (Use a GitHub noreply email for privacy if you prefer.)"
else
  echo "✅ Git user identity already set: $(git config --global user.name) <$(git config --global user.email)>"
fi

echo "✅ Git configured"

# Start PostgreSQL and wait for it to be ready
echo "📦 Starting PostgreSQL..."
sudo service postgresql start

echo "⏳ Waiting for PostgreSQL to be ready..."
until sudo -u postgres pg_isready; do
  sleep 1
done
echo "✅ PostgreSQL is ready"

# Create vscode user if it doesn't exist
echo "👤 Setting up database user..."
sudo -u postgres createuser -s vscode 2>/dev/null || echo "   User already exists"
sudo -u postgres psql -c "ALTER USER vscode WITH PASSWORD 'dev';" 2>/dev/null || true
echo "✅ Database user configured"

# Navigate to Rails app directory
cd "${CONTAINER_WORKSPACE_FOLDER:-/workspaces/git-team-reporting}"

# Install GitHub CLI (gh) so we can use `gh auth setup-git` for reliable
# HTTPS authentication on this private repo (avoids "could not read Username"
# + terminal prompts disabled errors when GIT_TERMINAL_PROMPT=0).
echo "🐙 Installing GitHub CLI (gh)..."
if ! command -v gh &> /dev/null; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq gh
  echo "✅ GitHub CLI installed"
else
  echo "✅ GitHub CLI already installed"
fi

# If the user has already authenticated gh (e.g. on previous container or via
# codespace secret), configure gh as the git credential helper for github.com.
if command -v gh &> /dev/null; then
  if gh auth status &>/dev/null; then
    echo "🔐 gh is logged in — setting up git credential helper..."
    gh auth setup-git || echo "   ⚠️ gh auth setup-git returned non-zero (continuing)"
    echo "✅ gh configured as git credential helper for github.com"
  else
    echo "⚠️  gh is installed but not logged in to GitHub."
    echo "   Run these commands once (login is bind-mounted from host ~/.config/gh and survives rebuilds):"
    echo "     gh auth login"
    echo "     gh auth setup-git"
  fi
fi

# Install Grok Build CLI (xAI agentic TUI) for seamless VSCode + agent workflows inside the dev container.
#
# GROK_HOME is the full directory bind-mounted from the host (~/.grok-devcontainer → /home/vscode/.grok).
# Do NOT set HOME to a fake directory for install — that breaks git/ssh/other tools. Use GROK_HOME only.
echo "🤖 Installing Grok Build CLI..."
GROK_HOME="${GROK_HOME:-$HOME/.grok}"
export GROK_HOME
mkdir -p "$GROK_HOME"
if [ ! -w "$GROK_HOME" ] || [ ! -O "$GROK_HOME" ]; then
  echo "   Fixing ownership of $GROK_HOME so Grok can install under bin/..."
  sudo chown -R "$(id -u):$(id -g)" "$GROK_HOME" 2>/dev/null || true
fi

# Idempotent PATH / GROK_HOME exports for interactive shells (avoid stacking duplicates on rebuild).
ensure_grok_shell_exports() {
  local rcfile="$1"
  [ -f "$rcfile" ] || touch "$rcfile" 2>/dev/null || return 0
  if ! grep -qF 'GROK_HOME=' "$rcfile" 2>/dev/null; then
    {
      echo ''
      echo '# Grok Build CLI (devcontainer)'
      echo 'export GROK_HOME="${GROK_HOME:-$HOME/.grok}"'
      echo 'export PATH="$GROK_HOME/bin:$PATH"'
    } >> "$rcfile" 2>/dev/null || true
  elif ! grep -qF 'GROK_HOME/bin' "$rcfile" 2>/dev/null && ! grep -qF '.grok/bin' "$rcfile" 2>/dev/null; then
    echo 'export PATH="${GROK_HOME:-$HOME/.grok}/bin:$PATH"' >> "$rcfile" 2>/dev/null || true
  fi
}
ensure_grok_shell_exports "$HOME/.bashrc"
ensure_grok_shell_exports "$HOME/.profile"
ensure_grok_shell_exports "$HOME/.zshrc"

# Run the grok block in a subshell so any failure here does not abort the rest of post-create (set -e).
(
  export GROK_HOME
  export PATH="$GROK_HOME/bin:$PATH"

  if [ -x "$GROK_HOME/bin/grok" ] || command -v grok >/dev/null 2>&1; then
    echo "✅ Grok Build CLI already present at $GROK_HOME/bin"
    # Best-effort self-update when the binary already survived a prior rebuild via the directory mount.
    if command -v grok >/dev/null 2>&1; then
      grok update 2>/dev/null || true
    fi
  else
    # IMPORTANT: pipe to `bash`, not `sh`. On Ubuntu containers /bin/sh is dash,
    # and the xAI installer script uses bash-specific syntax.
    set -o pipefail
    # Installer respects GROK_HOME (and falls back to $HOME/.grok). Keep real $HOME unchanged.
    if curl -fsSL https://x.ai/cli/install.sh | bash; then
      if [ -x "$GROK_HOME/bin/grok" ] || command -v grok >/dev/null 2>&1; then
        echo "✅ Grok Build CLI installed (use 'grok' or 'grok -p \"...\"' in the integrated terminal)"
        echo "   GROK_HOME=$GROK_HOME (host: ~/.grok-devcontainer — survives rebuilds)"
        echo "   Auth: 'grok login --device-auth' (headless) or 'grok login' / XAI_API_KEY"
        echo "   Tip: Run '/terminal-setup' inside Grok for VSCode terminal diagnostics"
      else
        echo "⚠️  Grok installer appeared to succeed but 'grok' is not on PATH / in GROK_HOME/bin."
      fi
    else
      echo "⚠️  Grok Build CLI install command failed (non-fatal)."
      echo "    Manual install (do NOT repoint HOME):"
      echo "      export GROK_HOME=\${GROK_HOME:-\$HOME/.grok}"
      echo "      curl -fsSL https://x.ai/cli/install.sh | bash"
      echo "      export PATH=\"\$GROK_HOME/bin:\$PATH\""
      echo "      grok login --device-auth"
    fi
  fi
) || echo "⚠️  Grok installation block hit an error but the rest of post-create will continue."

# Activate Grok on PATH for the remainder of *this* post-create script.
if [ -x "$GROK_HOME/bin/grok" ]; then
  export PATH="$GROK_HOME/bin:$PATH"
fi

# Install Ruby dependencies
echo "💎 Installing Ruby gems..."

# Prefer the Bundler version recorded in the lockfile if present
if [ -f Gemfile.lock ]; then
  BUNDLER_VERSION=$(grep -A1 "BUNDLED WITH" Gemfile.lock | tail -n1 | tr -d ' ')
  if [ -n "$BUNDLER_VERSION" ]; then
    echo "📌 Installing Bundler $BUNDLER_VERSION (from Gemfile.lock)"
    gem install bundler -v "$BUNDLER_VERSION" --no-document
  else
    gem install bundler --no-document
  fi
else
  gem install bundler --no-document
fi

bundle config set path 'vendor/bundle'
# Clear any stale lock before installing
rm -f vendor/bundle/ruby/*/bundler.lock 2>/dev/null || true
bundle install
echo "✅ Gems installed"

# Ruby LSP uses a composed Gemfile under .ruby-lsp/ only when ruby-lsp is NOT in the
# project Gemfile. Installing both causes duplicate gem declarations and Bundler errors.
if [ -f .ruby-lsp/Gemfile ] && ! grep -qE 'gem ["'\'']ruby-lsp["'\'']' Gemfile; then
  echo "💎 Installing Ruby LSP bundle..."
  BUNDLE_GEMFILE=.ruby-lsp/Gemfile bundle install
  echo "✅ Ruby LSP bundle installed"
elif grep -qE 'gem ["'\'']ruby-lsp["'\'']' Gemfile; then
  echo "✅ Ruby LSP provided by main Gemfile (skipping .ruby-lsp composed bundle)"
fi

# Install Node dependencies if package.json exists
echo "📦 Installing Node dependencies..."
corepack enable
if [ -f package.json ]; then
  yarn install
  echo "✅ Node dependencies installed"
else
  echo "   No package.json found, skipping"
fi

# Generate RSpec if needed
if grep -q 'rspec-rails' Gemfile; then
  if [ ! -f spec/spec_helper.rb ]; then
    echo "🧪 Generating RSpec configuration..."
    bin/rails generate rspec:install
    echo "✅ RSpec configured"
  else
    echo "✅ RSpec already configured"
  fi
fi

# Verify Chrome/Chromium installation
echo "🌐 Verifying Chrome/Chromium installation..."
if command -v chromium-browser &> /dev/null; then
  CHROME_VERSION=$(chromium-browser --version 2>/dev/null || echo "unknown")
  echo "✅ Chrome/Chromium installed: $CHROME_VERSION"
  echo "   Binary path: $(which chromium-browser)"
else
  echo "⚠️  Chrome/Chromium not found - system tests may fail"
fi

# Prepare databases
echo "🗄️  Preparing databases..."
bin/rails db:prepare
RAILS_ENV=test bin/rails db:prepare
echo "✅ Databases prepared"

# Precompile assets for test environment (required for system specs)
echo "🎨 Precompiling assets..."
RAILS_ENV=test bin/rails assets:precompile
echo "✅ Assets precompiled"

echo "🎉 Post-create setup complete! ($(date))"
echo "📝 Log saved to: $LOGFILE"
