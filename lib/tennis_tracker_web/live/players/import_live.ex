defmodule TennisTrackerWeb.Players.ImportLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis.PlayerCsvImport

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:error, nil)
     |> allow_upload(:csv_file,
       accept: ~w(.csv),
       max_entries: 1,
       max_file_size: 1_000_000
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Import Players
        <:subtitle>Upload a CSV file to bulk-import tennis players.</:subtitle>
        <:actions>
          <.link navigate={~p"/players"}>Back to Players</.link>
        </:actions>
      </.header>

      <form id="upload-form" phx-submit="import" phx-change="validate">
        <div class="space-y-4">
          <.live_file_input upload={@uploads.csv_file} />

          <%= for entry <- @uploads.csv_file.entries do %>
            <%= for err <- upload_errors(@uploads.csv_file, entry) do %>
              <p class="text-error text-sm">{upload_error_to_string(err)}</p>
            <% end %>
          <% end %>

          <div :if={@error} class="alert alert-error" id="import-error">
            <p>{@error}</p>
          </div>

          <.button type="submit">Import</.button>
        </div>
      </form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("import", _params, socket) do
    result =
      consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
        content = File.read!(path)
        {:ok, PlayerCsvImport.import_csv(content)}
      end)

    case result do
      [{:ok, count}] ->
        {:noreply,
         socket
         |> put_flash(:info, "Imported #{count} player(s).")
         |> push_navigate(to: ~p"/players")}

      [{:error, :invalid_headers, unknown}] ->
        {:noreply,
         assign(socket, :error, "Unknown column(s): #{Enum.join(unknown, ", ")}. Import cancelled.")}

      [{:error, :missing_required_headers, missing}] ->
        {:noreply,
         assign(socket, :error, "Missing required column(s): #{Enum.join(missing, ", ")}. Import cancelled.")}

      [{:error, :row_error, line, message}] ->
        {:noreply, assign(socket, :error, "Error on line #{line}: #{message}")}

      [] ->
        {:noreply, assign(socket, :error, "Please select a CSV file.")}
    end
  end

  defp upload_error_to_string(:too_large), do: "File is too large (max 1 MB)."
  defp upload_error_to_string(:not_accepted), do: "Only .csv files are accepted."
  defp upload_error_to_string(:too_many_files), do: "Only one file may be uploaded at a time."
end
