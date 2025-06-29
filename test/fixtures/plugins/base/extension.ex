defmodule Raxol.Terminal.Plugin.Base do
  @moduledoc """
  Base extension plugin for the Raxol terminal emulator.
  """

  def run_base_extension(args \\ []) do
    {:ok,
     %{
       extension: "base_extension",
       args: args,
       result: "Base extension executed successfully"
     }}
  end

  def get_base_info do
    %{
      name: "Base Extension",
      version: "1.0.0",
      description: "A base extension for the Raxol terminal emulator",
      author: "Test Author",
      license: "MIT"
    }
  end
end
