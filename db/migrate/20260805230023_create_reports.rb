# frozen_string_literal: true

class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :repository, null: true, foreign_key: { on_delete: :nullify }
      t.references :team, null: true, foreign_key: { on_delete: :nullify }
      t.string :repository_full_name, null: false
      t.string :team_name, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :date_range_label
      t.string :preset
      t.string :format, null: false, default: "html"
      t.string :filename, null: false
      t.text :content, null: false
      t.jsonb :metrics_payload, null: false, default: {}
      t.datetime :generated_at, null: false

      t.timestamps
    end

    add_index :reports, :generated_at
    add_index :reports, :format
    add_index :reports, :repository_full_name
  end
end
