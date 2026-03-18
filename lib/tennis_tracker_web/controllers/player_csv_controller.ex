defmodule TennisTrackerWeb.PlayerCSVController do
  use TennisTrackerWeb, :controller

  alias TennisTracker.Groups
  alias TennisTracker.Tennis.PlayerFilters

  @headers ~w(name ntrp_rating email phone_number eligible_18_plus eligible_40_plus eligible_55_plus)

  def export(conn, %{"group_slug" => group_slug} = params) do
    current_user = conn.assigns[:current_user]

    with {:ok, group} <- resolve_group(group_slug, current_user),
         :ok <- verify_membership(group.id, current_user) do
      name_search = params["name"] || ""
      ntrp_filter = PlayerFilters.parse_list_param(params["ntrp"])
      bracket_filter = PlayerFilters.parse_list_param(params["bracket"])

      players =
        PlayerFilters.fetch_players(name_search, ntrp_filter, bracket_filter,
          tenant: group.id,
          actor: current_user
        )

      csv =
        [@headers | Enum.map(players, &player_row/1)]
        |> Enum.map_join("\n", &Enum.join(&1, ","))

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", ~s(attachment; filename="players.csv"))
      |> send_resp(200, csv)
    else
      _ ->
        conn
        |> put_flash(:error, "Access denied or group not found.")
        |> redirect(to: ~p"/groups")
    end
  end

  defp resolve_group(slug, user) do
    try do
      group = Groups.get_group_by_slug!(slug, actor: user, authorize?: true)
      {:ok, group}
    rescue
      _ -> {:error, :not_found}
    end
  end

  defp verify_membership(_group_id, %{role: :admin}), do: :ok

  defp verify_membership(group_id, user) do
    case Groups.list_group_memberships_for_user(user.id, actor: user, authorize?: false) do
      {:ok, memberships} ->
        if Enum.any?(memberships, &(&1.group_id == group_id)), do: :ok, else: {:error, :forbidden}

      _ ->
        {:error, :forbidden}
    end
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
