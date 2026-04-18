defmodule TennisTracker.CredoChecks.NoRawLiveViewTuples do
  use Credo.Check,
    id: "TT0003",
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Prefer `ok/1`, `noreply/1`, and `error/1` helpers over raw return tuples in LiveViews.

      Building the return tuple by hand is noisy and breaks the pipeline style. Use the
      helpers from `TennisTrackerWeb.LiveHelpers` instead:

          # preferred
          socket
          |> assign(:foo, foo)
          |> noreply()

          # not preferred
          {:noreply, socket}
          {:noreply, socket |> assign(:foo, foo)}

          # preferred
          socket
          |> assign(:foo, foo)
          |> ok()

          # not preferred
          {:ok, socket}
          {:ok, socket |> assign(:foo, foo)}
      """
    ]

  @tags [:ok, :noreply, :error]

  @impl Credo.Check
  def run(%SourceFile{} = source_file, params) do
    if liveview_file?(source_file.filename) do
      ctx = Context.build(source_file, params, __MODULE__)
      result = Credo.Code.prewalk(source_file, &walk/2, ctx)
      result.issues
    else
      []
    end
  end

  # {:<tag>, socket} — bare socket variable
  defp walk({tag, {socket_var, meta, nil}} = ast, ctx)
       when tag in @tags and socket_var in [:socket, :new_socket] do
    {ast, put_issue(ctx, issue_for(ctx, tag, meta))}
  end

  # {:<tag>, socket |> ...} — pipe chain whose leftmost value is a socket variable
  defp walk({tag, {:|>, meta, _} = pipe} = ast, ctx) when tag in @tags do
    if socket_pipe?(pipe) do
      {ast, put_issue(ctx, issue_for(ctx, tag, meta))}
    else
      {ast, ctx}
    end
  end

  defp walk(ast, ctx), do: {ast, ctx}

  # Unwrap nested pipes to check if the leftmost value is a socket variable.
  defp socket_pipe?({:|>, _, [left | _]}), do: socket_pipe?(left)
  defp socket_pipe?({var, _, nil}) when var in [:socket, :new_socket], do: true
  defp socket_pipe?(_), do: false

  defp liveview_file?(filename) do
    String.contains?(filename, "/live/") and
      not String.ends_with?(filename, "_test.exs")
  end

  defp issue_for(ctx, tag, meta) do
    helper = helper_name(tag)

    format_issue(
      ctx,
      message: "Use `#{helper}/1` instead of a raw `{#{inspect(tag)}, socket}` tuple.",
      trigger: "{#{inspect(tag)}, socket}",
      line_no: meta[:line],
      column: meta[:column]
    )
  end

  defp helper_name(:ok), do: "ok"
  defp helper_name(:noreply), do: "noreply"
  defp helper_name(:error), do: "error"
end
