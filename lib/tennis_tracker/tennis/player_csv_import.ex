defmodule TennisTracker.Tennis.PlayerCsvImport do
  NimbleCSV.define(TennisTracker.CSV, separator: ",", escape: "\"")

  alias TennisTracker.Tennis
  alias TennisTracker.Repo

  @known_columns ~w(name email phone_number ntrp_rating eligible_18_plus eligible_40_plus eligible_55_plus)
  @required_columns ~w(name)
  @valid_ntrp ~w(2.5 3.0 3.5 4.0 4.5 5.0)
  @boolean_columns ~w(eligible_18_plus eligible_40_plus eligible_55_plus)

  @spec import_csv(binary(), keyword()) ::
          {:ok, non_neg_integer()}
          | {:error, :invalid_headers, [String.t()]}
          | {:error, :missing_required_headers, [String.t()]}
          | {:error, :row_error, pos_integer(), String.t()}
  def import_csv(content, opts \\ []) do
    rows = TennisTracker.CSV.parse_string(content, skip_headers: false)

    case rows do
      [] ->
        {:ok, 0}

      [header_row | data_rows] ->
        with {:ok, headers} <- validate_headers(header_row),
             {:ok, params_list} <- parse_rows(headers, data_rows) do
          insert_all(params_list, opts)
        end
    end
  end

  defp validate_headers(header_row) do
    headers = Enum.map(header_row, &String.trim/1)
    unknown = headers -- @known_columns
    missing = @required_columns -- headers

    cond do
      unknown != [] -> {:error, :invalid_headers, unknown}
      missing != [] -> {:error, :missing_required_headers, missing}
      true -> {:ok, headers}
    end
  end

  defp parse_rows(headers, data_rows) do
    result =
      data_rows
      |> Enum.with_index(2)
      |> Enum.reduce_while({:ok, []}, fn {row, line}, {:ok, acc} ->
        case coerce_row(headers, row, line) do
          {:ok, params} -> {:cont, {:ok, [params | acc]}}
          error -> {:halt, error}
        end
      end)

    case result do
      {:ok, params} -> {:ok, Enum.reverse(params)}
      error -> error
    end
  end

  defp coerce_row(headers, values, line) do
    padded = values ++ List.duplicate("", max(0, length(headers) - length(values)))

    headers
    |> Enum.zip(padded)
    |> Enum.reduce_while({:ok, %{}}, fn {header, raw_value}, {:ok, acc} ->
      value = String.trim(raw_value)

      case coerce_field(header, value, line) do
        {:ok, nil} -> {:cont, {:ok, acc}}
        {:ok, coerced} -> {:cont, {:ok, Map.put(acc, header, coerced)}}
        error -> {:halt, error}
      end
    end)
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

  defp coerce_field(col, "", _line) when col in @boolean_columns, do: {:ok, nil}
  defp coerce_field(col, "true", _line) when col in @boolean_columns, do: {:ok, true}
  defp coerce_field(col, "false", _line) when col in @boolean_columns, do: {:ok, false}

  defp coerce_field(col, value, line) when col in @boolean_columns do
    {:error, :row_error, line, "#{col} must be \"true\" or \"false\", got #{inspect(value)}"}
  end

  defp insert_all(params_list, opts) do
    group_id = Keyword.get(opts, :tenant)
    create_opts = Keyword.merge([return_notifications?: true], opts)

    Repo.transaction(fn ->
      params_list
      |> Enum.with_index(2)
      |> Enum.reduce_while({[], 0}, fn {params, line}, {notifs, count} ->
        params = if group_id, do: Map.put(params, :group_id, group_id), else: params

        case Tennis.create_player(params, create_opts) do
          {:ok, _player, notifications} ->
            {:cont, {notifs ++ notifications, count + 1}}

          {:error, error} ->
            Repo.rollback({:row_error, line, Exception.message(error)})
        end
      end)
    end)
    |> case do
      {:ok, {notifications, count}} ->
        Ash.Notifier.notify(notifications)
        {:ok, count}

      {:error, {:row_error, line, message}} ->
        {:error, :row_error, line, message}

      {:error, reason} ->
        {:error, :row_error, 0, inspect(reason)}
    end
  end
end
