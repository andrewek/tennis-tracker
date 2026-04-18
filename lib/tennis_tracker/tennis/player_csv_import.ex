defmodule TennisTracker.Tennis.PlayerCsvImport do
  @moduledoc false

  NimbleCSV.define(TennisTracker.CSV, separator: ",", escape: "\"")

  require Ash.Query

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{Tag, TagCategory}

  @known_columns ~w(name email phone_number ntrp_rating)
  @required_columns ~w(name)
  @valid_ntrp ~w(2.5 3.0 3.5 4.0 4.5 5.0)

  @spec import_csv(binary(), keyword()) ::
          {:ok,
           %{
             players: non_neg_integer(),
             categories_created: non_neg_integer(),
             tags_created: non_neg_integer()
           }}
          | {:error, :invalid_headers, [String.t()]}
          | {:error, :missing_required_headers, [String.t()]}
          | {:error, :row_error, pos_integer(), String.t()}
  def import_csv(content, opts \\ []) do
    rows = TennisTracker.CSV.parse_string(content, skip_headers: false)

    case rows do
      [] ->
        {:ok, %{players: 0, categories_created: 0, tags_created: 0}}

      [header_row | data_rows] ->
        with {:ok, {regular_headers, tag_columns}} <- validate_headers(header_row),
             all_headers = regular_headers ++ tag_columns,
             {:ok, parsed_rows} <- parse_rows(all_headers, data_rows) do
          {tag_map, categories_created, tags_created} = resolve_tag_columns(tag_columns, opts)

          case insert_all(parsed_rows, tag_map, opts) do
            {:ok, player_count} ->
              {:ok,
               %{
                 players: player_count,
                 categories_created: categories_created,
                 tags_created: tags_created
               }}

            error ->
              error
          end
        end
    end
  end

  defp validate_headers(header_row) do
    headers = Enum.map(header_row, &String.trim/1)

    {tag_headers, regular_headers} =
      Enum.split_with(headers, &String.starts_with?(&1, "tag:"))

    unknown = regular_headers -- @known_columns
    missing = @required_columns -- regular_headers

    # Validate tag column format: must be "tag:CategoryName:TagName" with non-empty segments
    invalid_tag_headers =
      Enum.filter(tag_headers, fn header ->
        case parse_tag_header_segments(header) do
          {:ok, _, _} -> false
          :error -> true
        end
      end)

    # Detect duplicate tag headers using normalized (downcased, trimmed) segment comparison
    normalized_keys =
      Enum.map(tag_headers, fn header ->
        case parse_tag_header_segments(header) do
          {:ok, cat, tag} -> "tag:#{String.downcase(cat)}:#{String.downcase(tag)}"
          :error -> header
        end
      end)

    duplicate_keys =
      normalized_keys
      |> Enum.frequencies()
      |> Enum.filter(fn {_, count} -> count > 1 end)
      |> Enum.map(fn {k, _} -> k end)

    cond do
      unknown != [] -> {:error, :invalid_headers, unknown}
      invalid_tag_headers != [] -> {:error, :invalid_headers, invalid_tag_headers}
      duplicate_keys != [] -> {:error, :invalid_headers, duplicate_keys}
      missing != [] -> {:error, :missing_required_headers, missing}
      true -> {:ok, {regular_headers, tag_headers}}
    end
  end

  # Splits "tag:CategoryName:TagName" into {:ok, cat_name, tag_name}.
  # Returns :error for malformed headers (wrong number of segments or empty segments).
  defp parse_tag_header_segments(header) do
    parts = header |> String.split(":") |> Enum.map(&String.trim/1)

    case parts do
      [_prefix, cat, tag] when byte_size(cat) > 0 and byte_size(tag) > 0 ->
        {:ok, cat, tag}

      _ ->
        :error
    end
  end

  defp parse_rows(headers, data_rows) do
    result =
      data_rows
      |> Enum.with_index(2)
      |> Enum.reduce_while({:ok, []}, fn {row, line}, {:ok, acc} ->
        case coerce_row(headers, row, line) do
          {:ok, row_data} -> {:cont, {:ok, [row_data | acc]}}
          error -> {:halt, error}
        end
      end)

    case result do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      error -> error
    end
  end

  # Returns {:ok, {player_params_map, [tag_header_strings_with_true_value]}}
  defp coerce_row(headers, values, line) do
    padded = values ++ List.duplicate("", max(0, length(headers) - length(values)))

    result =
      headers
      |> Enum.zip(padded)
      |> Enum.reduce_while({:ok, {%{}, []}}, fn {header, raw_value},
                                                {:ok, {params, tag_header_strings}} ->
        value = String.trim(raw_value)

        if String.starts_with?(header, "tag:") do
          case coerce_tag_cell(header, value, line) do
            {:ok, true} -> {:cont, {:ok, {params, [header | tag_header_strings]}}}
            {:ok, false} -> {:cont, {:ok, {params, tag_header_strings}}}
            error -> {:halt, error}
          end
        else
          case coerce_field(header, value, line) do
            {:ok, nil} ->
              {:cont, {:ok, {params, tag_header_strings}}}

            {:ok, coerced} ->
              {:cont, {:ok, {Map.put(params, header, coerced), tag_header_strings}}}

            error ->
              {:halt, error}
          end
        end
      end)

    case result do
      {:ok, {params, tag_header_strings}} -> {:ok, {params, Enum.reverse(tag_header_strings)}}
      error -> error
    end
  end

  defp coerce_tag_cell(_header, "", _line), do: {:ok, false}
  defp coerce_tag_cell(_header, nil, _line), do: {:ok, false}

  defp coerce_tag_cell(header, value, line) do
    if String.downcase(value) == "true" do
      {:ok, true}
    else
      {:error, :row_error, line,
       "tag column '#{header}' has invalid value '#{value}'; expected 'true' or empty"}
    end
  end

  defp coerce_field("name", "", line),
    do: {:error, :row_error, line, "name cannot be blank"}

  defp coerce_field("name", value, _line), do: {:ok, value}

  defp coerce_field("email", "", _line), do: {:ok, nil}
  defp coerce_field("email", value, _line), do: {:ok, value}

  defp coerce_field("phone_number", "", _line), do: {:ok, nil}
  defp coerce_field("phone_number", value, _line), do: {:ok, value}

  defp coerce_field("ntrp_rating", "", _line), do: {:ok, nil}

  defp coerce_field("ntrp_rating", value, line) do
    if value in @valid_ntrp do
      {:ok, Decimal.new(value)}
    else
      {:error, :row_error, line,
       "ntrp_rating #{inspect(value)} is not valid (must be one of 2.5, 3.0, 3.5, 4.0, 4.5, 5.0)"}
    end
  end

  # Returns {%{header_string => tag_id}, categories_created_count, tags_created_count}
  defp resolve_tag_columns([], _opts), do: {%{}, 0, 0}

  defp resolve_tag_columns(tag_columns, opts) do
    Enum.reduce(tag_columns, {%{}, 0, 0}, fn header, {map, cat_count, tag_count} ->
      {:ok, cat_name, tag_name} = parse_tag_header_segments(header)

      {category, new_cat} = find_or_create_category(cat_name, opts)
      {tag, new_tag} = find_or_create_tag(tag_name, category, opts)

      {Map.put(map, header, tag.id), cat_count + new_cat, tag_count + new_tag}
    end)
  end

  defp find_or_create_category(name, opts) do
    group_id = Keyword.fetch!(opts, :tenant)
    actor = Keyword.get(opts, :actor)
    name_lower = String.downcase(String.trim(name))

    existing =
      TagCategory
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(fragment("lower(?)", name) == ^name_lower)
      |> Ash.read_one!(domain: Tennis, tenant: group_id)

    case existing do
      nil ->
        category =
          TagCategory
          |> Ash.Changeset.for_create(:create, %{name: name, group_id: group_id},
            domain: Tennis,
            tenant: group_id,
            authorize?: false
          )
          |> Ash.create!()

        {category, 1}

      category ->
        {category, 0}
    end
  end

  defp find_or_create_tag(name, category, opts) do
    group_id = Keyword.fetch!(opts, :tenant)
    actor = Keyword.get(opts, :actor)
    name_lower = String.downcase(String.trim(name))

    existing =
      Tag
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(
        fragment("lower(?)", name) == ^name_lower and tag_category_id == ^category.id
      )
      |> Ash.read_one!(domain: Tennis, tenant: group_id)

    case existing do
      nil ->
        tag =
          Tag
          |> Ash.Changeset.for_create(
            :create,
            %{name: name, group_id: group_id, tag_category_id: category.id},
            domain: Tennis,
            tenant: group_id,
            authorize?: false
          )
          |> Ash.create!()

        {tag, 1}

      tag ->
        {tag, 0}
    end
  end

  defp insert_all(rows, tag_map, opts) do
    group_id = Keyword.get(opts, :tenant)
    create_opts = Keyword.delete(opts, :return_notifications?)

    result =
      Ash.transact(TennisTracker.Tennis.Player, fn ->
        rows
        |> Enum.with_index(2)
        |> Enum.reduce_while({:ok, 0}, fn {{params, tag_header_strings}, line}, {:ok, count} ->
          params = if group_id, do: Map.put(params, :group_id, group_id), else: params

          case Tennis.create_player(params, create_opts) do
            {:ok, player} ->
              case create_player_tags(player.id, tag_header_strings, tag_map, opts) do
                :ok -> {:cont, {:ok, count + 1}}
                {:error, error} -> {:halt, {:error, {:row_error, line, Exception.message(error)}}}
              end

            {:error, error} ->
              {:halt, {:error, {:row_error, line, Exception.message(error)}}}
          end
        end)
      end)

    case result do
      {:ok, {:ok, count}} -> {:ok, count}
      {:error, {:row_error, line, message}} -> {:error, :row_error, line, message}
      {:error, reason} -> {:error, :row_error, 0, inspect(reason)}
    end
  end

  defp create_player_tags(player_id, tag_header_strings, tag_map, opts) do
    group_id = Keyword.get(opts, :tenant)
    actor = Keyword.get(opts, :actor)

    Enum.reduce_while(tag_header_strings, :ok, fn header, :ok ->
      case Map.fetch(tag_map, header) do
        {:ok, tag_id} ->
          case Tennis.create_player_tag(
                 %{player_id: player_id, tag_id: tag_id, group_id: group_id},
                 tenant: group_id,
                 actor: actor
               ) do
            {:ok, _} -> {:cont, :ok}
            {:error, error} -> {:halt, {:error, error}}
          end

        :error ->
          {:cont, :ok}
      end
    end)
  end
end
