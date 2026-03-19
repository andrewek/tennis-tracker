defmodule TennisTrackerWeb.Players.ImportLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis.PlayerCsvImport

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:error, nil)
    |> allow_upload(:csv_file,
      accept: ~w(.csv),
      max_entries: 1,
      max_file_size: 1_000_000
    )
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_group={@current_group}>
      <.page_header
        title="Import Players"
        back_href={~p"/g/#{@current_group.slug}/players"}
        back_label="Players"
      >
        <:subtitle>Upload a CSV file to bulk-import tennis players.</:subtitle>
      </.page_header>

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
    socket |> noreply()
  end

  @impl true
  def handle_event("import", _params, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    group_slug = socket.assigns.current_group.slug

    result =
      consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
        content = File.read!(path)
        {:ok, PlayerCsvImport.import_csv(content, tenant: group_id, actor: current_user)}
      end)

    case result do
      [{:ok, count}] ->
        socket
        |> put_flash(:info, "Imported #{count} player(s).")
        |> push_navigate(to: ~p"/g/#{group_slug}/players")
        |> noreply()

      [{:error, :invalid_headers, unknown}] ->
        socket
        |> assign(:error, "Unknown column(s): #{Enum.join(unknown, ", ")}. Import cancelled.")
        |> noreply()

      [{:error, :missing_required_headers, missing}] ->
        socket
        |> assign(
          :error,
          "Missing required column(s): #{Enum.join(missing, ", ")}. Import cancelled."
        )
        |> noreply()

      [{:error, :row_error, line, message}] ->
        socket
        |> assign(:error, "Error on line #{line}: #{message}")
        |> noreply()

      [] ->
        socket
        |> assign(:error, "Please select a CSV file.")
        |> noreply()
    end
  end

  defp upload_error_to_string(:too_large), do: "File is too large (max 1 MB)."
  defp upload_error_to_string(:not_accepted), do: "Only .csv files are accepted."
  defp upload_error_to_string(:too_many_files), do: "Only one file may be uploaded at a time."
end
