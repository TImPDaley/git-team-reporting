FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Avoid tzdata prompts
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]

# Base build deps for Ruby 3.4.x and common Rails gems
RUN apt-get update && apt-get install -y --no-install-recommends \
  curl ca-certificates gnupg2 unzip \
  build-essential autoconf bison \
  libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev \
  libgdbm-dev libgmp-dev \
  libsqlite3-dev libpq-dev \
  git imagemagick libvips42 libvips-dev tzdata pkg-config ripgrep \
  # dig/nslookup for DNS debugging
  dnsutils \
  && rm -rf /var/lib/apt/lists/*

# Ensure sudo exists and allow passwordless sudo for the vscode user (dev only)
RUN apt-get update && apt-get install -y --no-install-recommends sudo \
  && echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-vscode \
  && chmod 0440 /etc/sudoers.d/90-vscode \
  && rm -rf /var/lib/apt/lists/*

# Node.js 22 LTS (for Rails jsbundling/esbuild) + Corepack (Yarn)
# Using the modern NodeSource repository setup method
RUN mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends nodejs \
  && corepack enable \
  && rm -rf /var/lib/apt/lists/*

# Chrome/Chromium for system tests (Capybara with Selenium)
# Install Chromium and all required dependencies for headless operation
RUN apt-get update && apt-get install -y --no-install-recommends \
  chromium-browser \
  chromium-chromedriver \
  libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
  libcups2 libxkbcommon0 libatspi2.0-0 libxcomposite1 \
  libxdamage1 libxrandr2 libgbm1 libasound2t64 \
  libxfixes3 libxext6 libxi6 libxrender1 libxtst6 \
  libpangocairo-1.0-0 libpango-1.0-0 libcairo2 libdbus-1-3 \
  xvfb \
  && rm -rf /var/lib/apt/lists/*

# Configure Chrome/Chromium for headless operation
# Create symlinks for common Chrome paths
RUN ln -sf /usr/bin/chromium-browser /usr/bin/chromium \
  && ln -sf /usr/bin/chromium-browser /usr/bin/google-chrome \
  && ln -sf /usr/bin/chromium-browser /usr/bin/chrome

# Set Chrome environment variables for headless operation
ENV CHROME_BIN=/usr/bin/chromium-browser
ENV CHROMIUM_BIN=/usr/bin/chromium-browser

# System-wide rbenv (works well in devcontainers & non-login shells)
ENV RBENV_ROOT=/usr/local/rbenv
ENV PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"

RUN git clone https://github.com/rbenv/rbenv.git "$RBENV_ROOT" \
  && mkdir -p "$RBENV_ROOT"/plugins \
  && git clone https://github.com/rbenv/ruby-build.git "$RBENV_ROOT"/plugins/ruby-build \
  && rbenv --version

# Build & install Ruby (pin to latest stable)
ARG RUBY_VERSION=3.4.9
RUN RUBY_CONFIGURE_OPTS="--with-openssl-dir=/usr" rbenv install "$RUBY_VERSION" \
  && rbenv global "$RUBY_VERSION" \
  && gem update --system --no-document \
  && gem install bundler --no-document

# Install Rails (pin to latest stable)
ARG RAILS_VERSION=8.1.3
RUN gem install rails -v "$RAILS_VERSION" --no-document \
  && rbenv rehash

# Pin Solargraph globally for CLI use (must match Gemfile.lock; 0.60.x breaks with RBS)
RUN gem install solargraph -v 0.59.2 --no-document \
  && rbenv rehash

# Fix permissions so vscode user can install gems
RUN chown -R vscode:vscode /usr/local/rbenv

# Ensure rbenv is initialized for all users and shells
RUN echo 'export RBENV_ROOT="/usr/local/rbenv"' > /etc/profile.d/rbenv.sh \
  && echo 'export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"' >> /etc/profile.d/rbenv.sh \
  && echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh

# PostgreSQL server & client with proper setup
RUN apt-get update && apt-get install -y --no-install-recommends \
  postgresql postgresql-contrib postgresql-client \
  && rm -rf /var/lib/apt/lists/*

# Configure PostgreSQL for development
RUN service postgresql start \
  && sudo -u postgres createuser -s vscode \
  && sudo -u postgres psql -c "ALTER USER vscode WITH PASSWORD 'dev';" \
  && service postgresql stop

# Configure PostgreSQL to start automatically
RUN update-rc.d postgresql defaults || true

# Create startup script for PostgreSQL
RUN printf '%s\n' \
  '#!/bin/bash' \
  'set -e' \
  '' \
  '# Start PostgreSQL if not running' \
  'if ! pgrep -x "postgres" > /dev/null; then' \
  '  sudo service postgresql start' \
  '  # Wait for PostgreSQL to be ready' \
  '  until sudo -u postgres pg_isready > /dev/null 2>&1; do' \
  '    sleep 1' \
  '  done' \
  'fi' > /usr/local/bin/start-postgres \
  && chmod +x /usr/local/bin/start-postgres

# Create a background service that ensures PostgreSQL stays running
RUN printf '%s\n' \
  '#!/bin/bash' \
  'set +e' \
  '' \
  'while true; do' \
  '  if ! pgrep -x "postgres" > /dev/null; then' \
  '    /usr/local/bin/start-postgres || echo "⚠️ start-postgres failed; retrying in 30s"' \
  '  fi' \
  '  sleep 30' \
  'done' > /usr/local/bin/postgres-watchdog \
  && chmod +x /usr/local/bin/postgres-watchdog

# Useful defaults
ENV BUNDLE_JOBS=4 BUNDLE_RETRY=3

ARG TZ=America/Detroit
ENV TZ=${TZ}
RUN ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
  && echo "${TZ}" > /etc/timezone
