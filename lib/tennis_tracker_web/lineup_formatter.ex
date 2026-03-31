defmodule TennisTrackerWeb.LineupFormatter do
  @moduledoc """
  Formats match lineup data as plain text for clipboard copying.

  Header format: "{date_str} · {time_str} ({venue_name})"
  e.g. "Sun, Mar 29 · 2:00 PM (Genesis Westroads)"

  For each clipboard-included slot in sort_order:
    slot_name:\n
    player_name (one per line, sorted alphabetically)\n
    --- (if no players assigned)\n
  Slots separated by a blank line.
  """

  import TennisTrackerWeb.MatchHelpers, only: [format_match_datetime: 2]

  @doc """
  Formats the lineup for a match into clipboard text.

  - match: loaded with :location
  - slots: TeamLineupSlot records in sort_order, loaded with :team
  - assignments: MatchLineupAssignment records, loaded with :player and :team_lineup_slot
  """
  def format(match, slots, assignments) do
    header = build_header(match)

    clipboard_slots =
      slots
      |> Enum.filter(& &1.include_in_clipboard)
      |> Enum.sort_by(& &1.sort_order)

    if clipboard_slots == [] do
      header
    else
      slot_blocks =
        Enum.map(clipboard_slots, fn slot ->
          players =
            assignments
            |> Enum.filter(&(&1.team_lineup_slot_id == slot.id))
            |> Enum.map(& &1.player.name)
            |> Enum.sort()

          player_lines =
            if players == [] do
              "---"
            else
              Enum.join(players, "\n")
            end

          "#{slot.name}:\n#{player_lines}"
        end)

      header <> "\n\n" <> Enum.join(slot_blocks, "\n\n")
    end
  end

  defp build_header(match) do
    {date_str, time_str} = format_match_datetime(match.match_start_datetime, match.timezone)

    venue =
      case match.location do
        nil -> nil
        %{name: name} -> name
      end

    if venue do
      "#{date_str} · #{time_str} (#{venue})"
    else
      "#{date_str} · #{time_str}"
    end
  end
end
