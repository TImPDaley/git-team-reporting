# frozen_string_literal: true

class CreateRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :repositories do |t|
      t.references :team, null: false, foreign_key: true
      t.string :owner, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :repositories, [ :owner, :name ], unique: true
  end
end
