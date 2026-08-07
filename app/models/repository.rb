# frozen_string_literal: true

class Repository < ApplicationRecord
  belongs_to :team
  has_many :reports, dependent: :nullify

  normalizes :owner, with: ->(owner) { owner.to_s.strip }
  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :owner, presence: true
  validates :name, presence: true
  validates :name, uniqueness: { scope: :owner, case_sensitive: false }

  scope :ordered, -> { order(:owner, :name) }

  def full_name
    "#{owner}/#{name}"
  end
end
