# frozen_string_literal: true

module Reports
  # Matches GitHub activity identities to known team members by username or email.
  class DeveloperMatcher
    Match = Data.define(:team_member, :key, :matched_by)

    def initialize(team_members)
      @by_username = {}
      @by_email = {}

      team_members.each do |member|
        if member.github_username.present?
          @by_username[normalize_username(member.github_username)] = member
        end
        if member.email.present?
          @by_email[normalize_email(member.email)] = member
        end
      end
    end

    def match(login: nil, email: nil)
      if login.present?
        member = @by_username[normalize_username(login)]
        return Match.new(team_member: member, key: member_key(member), matched_by: :github_username) if member
      end

      if email.present?
        member = @by_email[normalize_email(email)]
        return Match.new(team_member: member, key: member_key(member), matched_by: :email) if member
      end

      Match.new(team_member: nil, key: unmatched_key(login: login, email: email), matched_by: :unmatched)
    end

    private

    def normalize_username(value)
      value.to_s.strip.delete_prefix("@").downcase
    end

    def normalize_email(value)
      value.to_s.strip.downcase
    end

    def member_key(member)
      "member:#{member.id}"
    end

    def unmatched_key(login:, email:)
      if login.present?
        "login:#{normalize_username(login)}"
      elsif email.present?
        "email:#{normalize_email(email)}"
      else
        "unknown"
      end
    end
  end
end
