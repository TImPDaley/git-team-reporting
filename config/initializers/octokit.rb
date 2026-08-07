# frozen_string_literal: true

# Enable auto-pagination for Octokit list endpoints by default.
Octokit.configure do |c|
  c.auto_paginate = true
end
