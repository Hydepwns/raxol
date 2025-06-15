%{
  configs: [
    %{
      name: "terminal",
      files: %{
        excluded: [~r"input_handler\.ex$", ~r"window_handlers\.ex$"]
      },
      checks: []
    }
  ]
}
