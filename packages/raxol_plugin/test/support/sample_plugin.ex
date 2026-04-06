defmodule Raxol.Plugin.Test.SamplePlugin do
  @moduledoc false
  use Raxol.Plugin

  @impl true
  def init(config) do
    {:ok, %{config: config, events: []}}
  end
end
