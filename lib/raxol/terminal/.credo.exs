%{
  configs: [
    %{
      name: "terminal",
      files: %{
        excluded: [~r"input_handler\.ex$"]
      },
      checks: []
    }
  ]
}
