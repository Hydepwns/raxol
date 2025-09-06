defmodule Raxol.Terminal.Split.Common do
  @moduledoc """
  Common utilities and shared logic for terminal split modules.
  """

  @doc """
  Common start_link logic for split-related GenServers.
  """
  def start_link(module, opts \\ []) do
    opts = case is_map(opts) do
      true -> Enum.into(opts, [])
      false -> opts
    end

    name =
      case Mix.env() == :test do
        true -> Raxol.Test.ProcessNaming.unique_name(module, opts)
        false -> Keyword.get(opts, :name, module)
      end

    GenServer.start_link(module, opts, name: name)
  end
end
