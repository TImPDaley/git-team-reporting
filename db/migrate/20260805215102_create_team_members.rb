# frozen_string_literal: true

class CreateTeamMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :team_members do |t|
      t.references :team, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :github_username

      t.timestamps
    end

    add_index :team_members, [ :team_id, :email ], unique: true
    add_index :team_members, [ :team_id, :github_username ],
              unique: true,
              where: "github_username IS NOT NULL AND github_username <> ''"
  end
end
