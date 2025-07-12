defmodule Raxol.Terminal.Split.Common do
  @moduledoc """
  Common utilities and shared logic for terminal split modules.
  """

  @doc """
  Common start_link logic for split-related GenServers.
  """
  def start_link(module, opts \\ []) do
    opts = if is_map(opts), do: Enum.into(opts, []), else: opts

    name =
      if Mix.env() == :test do
        Raxol.Test.ProcessNaming.unique_name(module, opts)
      else
        Keyword.get(opts, :name, module)
      end

    GenServer.start_link(module, opts, name: name)
  end
end
