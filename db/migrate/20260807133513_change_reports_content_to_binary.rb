# frozen_string_literal: true

class ChangeReportsContentToBinary < ActiveRecord::Migration[8.1]
  def up
    # Store report bodies as bytea so PDF binary is safe alongside text formats.
    execute <<~SQL.squish
      ALTER TABLE reports
      ALTER COLUMN content TYPE bytea
      USING convert_to(content, 'UTF8')
    SQL
  end

  def down
    # PDF rows store arbitrary binary; convert_from(..., 'UTF8') would fail or corrupt.
    raise ActiveRecord::IrreversibleMigration,
          "reports.content may contain binary (PDF) data; cannot safely convert bytea back to UTF-8 text"
  end
end
