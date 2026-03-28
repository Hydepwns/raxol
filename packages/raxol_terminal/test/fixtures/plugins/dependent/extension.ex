defmodule Raxol.Terminal.Plugin.Dependent do
  @moduledoc """
  Dependent extension plugin for the Raxol terminal emulator.
  """

  def run_dependent_extension(args \\ []) do
    {:ok,
     %{
       extension: "dependent_extension",
       args: args,
       result: "Dependent extension executed successfully"
     }}
  end

  def get_dependent_info do
    %{
      name: "Dependent Extension",
      version: "1.0.0",
      description: "A dependent extension for the Raxol terminal emulator",
      author: "Test Author",
      license: "MIT"
    }
  end
end
