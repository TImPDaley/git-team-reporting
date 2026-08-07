# frozen_string_literal: true

module Github
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class NotFoundError < Error; end
  class UnauthorizedError < Error; end
  class RateLimitError < Error; end
  class ApiError < Error; end
end
