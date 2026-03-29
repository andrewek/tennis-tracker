defmodule TennisTrackerWeb.PlayerCSVController do
  use TennisTrackerWeb, :controller

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.PlayerFilters

  @headers ~w(name ntrp_rating email phone_number)

  def export(conn, params) do
    current_user = conn.assigns.current_user
    group = conn.assigns.current_group

    name_search = params["name"] || ""
    ntrp_filter = PlayerFilters.parse_list_param(params["ntrp"])
    tag_filter = parse_tag_filter(params["tags"], group.id, current_user)

    players =
      PlayerFilters.fetch_players(name_search, ntrp_filter, tag_filter,
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
  end

  defp parse_tag_filter(nil, _group_id, _actor), do: %{include: %{}, show_untagged: []}

  defp parse_tag_filter(tag_ids, group_id, actor) when is_list(tag_ids) do
    all_tags =
      Tennis.list_tag_categories!(load: [:tags], tenant: group_id, actor: actor)
      |> Enum.flat_map(& &1.tags)

    valid_tag_ids = MapSet.new(all_tags, & &1.id)

    include =
      tag_ids
      |> Enum.filter(&MapSet.member?(valid_tag_ids, &1))
      |> Enum.reduce(%{}, fn tag_id, acc ->
        tag = Enum.find(all_tags, &(&1.id == tag_id))
        category_id = tag && tag.tag_category_id

        if category_id do
          Map.update(acc, category_id, [tag_id], &[tag_id | &1])
        else
          acc
        end
      end)

    %{include: include, show_untagged: []}
  end

  defp parse_tag_filter(tag_id, group_id, actor) when is_binary(tag_id),
    do: parse_tag_filter([tag_id], group_id, actor)

  defp player_row(player) do
    [
      player.name,
      player.ntrp_rating,
      player.email,
      player.phone_number
    ]
    |> Enum.map(&csv_value/1)
  end

  defp csv_value(nil), do: ""
  defp csv_value(%Decimal{} = v), do: Decimal.to_string(v)

  defp csv_value(v) when is_binary(v) do
    if String.contains?(v, [",", "\"", "\n"]) do
      ~s("#{String.replace(v, "\"", "\"\"")}")
    else
      v
    end
  end
end
