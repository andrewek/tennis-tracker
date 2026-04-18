defmodule TennisTracker.CredoChecks.NoUnless do
  use Credo.Check,
    id: "TT0002",
    base_priority: :high,
    category: :refactor,
    explanations: [
      check: """
      Avoid `unless` — use `if` with a positive condition instead.

      `unless` is harder to read, especially when combined with `else` or negated
      conditions. Prefer an explicit `if`:

          # preferred
          if authorized? do
            proceed()
          else
            redirect()
          end

          # not preferred
          unless authorized? do
            redirect()
          else
            proceed()
          end
      """
    ]

  @impl Credo.Check
  def run(%SourceFile{} = source_file, params) do
    ctx = Context.build(source_file, params, __MODULE__)
    result = Credo.Code.prewalk(source_file, &walk/2, ctx)
    result.issues
  end

  defp walk({:unless, meta, _args} = ast, ctx) do
    {ast, put_issue(ctx, issue_for(ctx, meta))}
  end

  defp walk(ast, ctx), do: {ast, ctx}

  defp issue_for(ctx, meta) do
    format_issue(
      ctx,
      message: "Avoid `unless` — use `if` with a positive condition instead.",
      trigger: "unless",
      line_no: meta[:line],
      column: meta[:column]
    )
  end
end
