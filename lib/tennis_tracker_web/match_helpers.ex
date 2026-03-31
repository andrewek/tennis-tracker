defmodule TennisTrackerWeb.MatchHelpers do
  @doc """
  Formats a UTC DateTime into a {date_str, time_str} tuple in the given timezone.
  Uses abbreviated format: "Wed, Mar 4" and "10:00 AM".
  """
  def format_match_datetime(%DateTime{} = utc_dt, timezone) do
    tz = timezone || "America/Chicago"
    local = DateTime.shift_zone!(utc_dt, tz)
    date_str = Calendar.strftime(local, "%a, %b %-d")

    %DateTime{hour: h, minute: m} = local

    {hour, ampm} =
      if h >= 12,
        do: {rem(h, 12) |> then(&if(&1 == 0, do: 12, else: &1)), "PM"},
        else: {if(h == 0, do: 12, else: h), "AM"}

    minute_str = m |> Integer.to_string() |> String.pad_leading(2, "0")
    time_str = "#{hour}:#{minute_str} #{ampm}"
    {date_str, time_str}
  end

  @doc """
  Formats a home/away label for a match. e.g. "HOME v. Opponent" or "AWAY v. Opponent".
  """
  def format_home_or_away(:home, opponent), do: "HOME v. #{opponent}"
  def format_home_or_away(:away, opponent), do: "AWAY v. #{opponent}"

  @doc """
  Parses date and time strings with a timezone and returns {:ok, utc_datetime} or {:error, reason}.
  Handles ambiguous/gap times from DST transitions.
  """
  def build_match_datetime_params(date_str, time_str, timezone) do
    with {:ok, date} <- Date.from_iso8601(date_str || ""),
         {:ok, time} <- Time.from_iso8601("#{time_str || ""}:00"),
         {:ok, naive} <- NaiveDateTime.new(date, time),
         result <- DateTime.from_naive(naive, timezone) do
      case result do
        {:ok, dt} ->
          {:ok, DateTime.shift_zone!(dt, "Etc/UTC")}

        {:ambiguous, _first, second} ->
          {:ok, DateTime.shift_zone!(second, "Etc/UTC")}

        {:gap, _before, after_gap} ->
          {:ok, DateTime.shift_zone!(after_gap, "Etc/UTC")}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
