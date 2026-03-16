defmodule TennisTracker.Repo.Migrations.BackfillMatchStartDatetime do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE matches
    SET match_start_datetime = (
      (match_date::text || ' ' || match_time::text)::timestamp AT TIME ZONE timezone
    )
    """)
  end

  def down do
    execute("UPDATE matches SET match_start_datetime = NULL")
  end
end
