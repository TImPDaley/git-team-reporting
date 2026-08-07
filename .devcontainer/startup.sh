#!/bin/bash
set -e

# Log to file for debugging
LOGFILE="/tmp/startup.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "🚀 Starting Git Team Reporting environment setup... ($(date))"

# Check if PostgreSQL is already running, start if not
if ! sudo -u postgres pg_isready > /dev/null 2>&1; then
  echo "📦 Starting PostgreSQL..."
  sudo service postgresql start
  
  # Wait for PostgreSQL to be ready
  echo "⏳ Waiting for PostgreSQL to be ready..."
  until sudo -u postgres pg_isready; do
    sleep 1
  done
  echo "✅ PostgreSQL is ready"
else
  echo "✅ PostgreSQL is already running"
fi

# Navigate to Rails app directory
cd "${CONTAINER_WORKSPACE_FOLDER:-/workspaces/git_team_reporting}"

# Prepare database (creates if needed, runs migrations)
echo "🗄️  Preparing database..."
echo "   Current directory: $(pwd)"
echo "   Rails version: $(bin/rails --version)"
echo "   Running: bin/rails db:prepare"

if bin/rails db:prepare 2>&1; then
  echo "✅ Database prepared successfully"
else
  EXIT_CODE=$?
  echo "⚠️  Database preparation failed with exit code: $EXIT_CODE"
  echo "   Continuing anyway..."
fi

# Prepare test database
echo "🧪 Preparing test database..."
echo "   Running: RAILS_ENV=test bin/rails db:prepare"

if RAILS_ENV=test bin/rails db:prepare 2>&1; then
  echo "✅ Test database prepared successfully"
else
  EXIT_CODE=$?
  echo "⚠️  Test database preparation failed with exit code: $EXIT_CODE"
  echo "   Continuing anyway..."
fi

echo "🎉 Environment setup complete! ($(date))"
echo "📝 Startup log saved to: $LOGFILE"
