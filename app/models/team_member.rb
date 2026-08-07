# frozen_string_literal: true

class TeamMember < ApplicationRecord
  belongs_to :team

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }
  normalizes :github_username, with: ->(username) {
    value = username.to_s.strip.delete_prefix("@")
    value.presence
  }
  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :team_id, case_sensitive: false }
  validates :github_username, uniqueness: { scope: :team_id, allow_nil: true, case_sensitive: false }

  scope :ordered, -> { order(:name) }

  def display_label
    if github_username.present?
      "#{name} (@#{github_username})"
    else
      "#{name} <#{email}>"
    end
  end
end
