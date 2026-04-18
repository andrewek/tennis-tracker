%{
  configs: [
    %{
      name: "default",
      plugins: [{AshCredo, []}],
      checks: %{
        enabled: [
          {TennisTracker.CredoChecks.NoHtmlMatch, []}
        ]
      }
    }
  ]
}
