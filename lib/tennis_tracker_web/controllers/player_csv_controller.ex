defmodule TennisTrackerWeb.PlayerCSVController do
  use TennisTrackerWeb, :controller

  alias TennisTracker.Tennis.PlayerFilters

  @headers ~w(name ntrp_rating email phone_number eligible_18_plus eligible_40_plus eligible_55_plus)

  def export(conn, params) do
    name_search = params["name"] || ""
    ntrp_filter = PlayerFilters.parse_list_param(params["ntrp"])
    bracket_filter = PlayerFilters.parse_list_param(params["bracket"])

    players = PlayerFilters.fetch_players(name_search, ntrp_filter, bracket_filter)

    csv =
      [@headers | Enum.map(players, &player_row/1)]
      |> Enum.map_join("\n", &Enum.join(&1, ","))

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="players.csv"))
    |> send_resp(200, csv)
  end

  defp player_row(player) do
    [
      player.name,
      player.ntrp_rating,
      player.email,
      player.phone_number,
      player.eligible_18_plus,
      player.eligible_40_plus,
      player.eligible_55_plus
    ]
    |> Enum.map(&csv_value/1)
  end

  defp csv_value(nil), do: ""
  defp csv_value(v) when is_boolean(v), do: to_string(v)
  defp csv_value(%Decimal{} = v), do: Decimal.to_string(v)

  defp csv_value(v) when is_binary(v) do
    if String.contains?(v, [",", "\"", "\n"]) do
      ~s("#{String.replace(v, "\"", "\"\"")}")
    else
      v
    end
  end
end
