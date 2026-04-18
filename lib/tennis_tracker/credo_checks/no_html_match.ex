defmodule TennisTracker.CredoChecks.NoHtmlMatch do
  use Credo.Check,
    id: "TT0001",
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Prefer `has_element?/2` or `has_element?/3` over `html =~` for LiveView test assertions.

      Using `html =~` performs a raw string search on the rendered HTML, which can produce
      false positives (matching in attribute values, comments, encoded entities, etc.) and
      gives poor failure messages.

          # preferred
          assert has_element?(view, "h1", "Player Name")
          assert has_element?(view, "#player-\#{player.id}")

          # not preferred
          assert html =~ "Player Name"
      """
    ]

  @impl Credo.Check
  def run(%SourceFile{} = source_file, params) do
    if test_file?(source_file.filename) do
      ctx = Context.build(source_file, params, __MODULE__)
      result = Credo.Code.prewalk(source_file, &walk/2, ctx)
      result.issues
    else
      []
    end
  end

  # Match any `<var> =~ <value>` where the left-hand variable is named `html`
  defp walk({:=~, meta, [{:html, _, nil} | _]} = ast, ctx) do
    {ast, put_issue(ctx, issue_for(ctx, meta))}
  end

  defp walk(ast, ctx), do: {ast, ctx}

  defp test_file?(filename) do
    String.contains?(filename, "/test/") or String.ends_with?(filename, "_test.exs")
  end

  defp issue_for(ctx, meta) do
    format_issue(
      ctx,
      message: "Use `has_element?/2` or `has_element?/3` instead of `html =~` for LiveView assertions.",
      trigger: "html =~",
      line_no: meta[:line],
      column: meta[:column]
    )
  end
end
