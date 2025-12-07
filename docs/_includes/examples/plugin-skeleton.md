## Plugin Skeleton

```elixir
defmodule MyApp.Plugins.MyPlugin do
  @behaviour Raxol.Core.Runtime.Plugins.Plugin
  use GenServer

  def manifest do
    %{
      name: "my-plugin",
      version: "1.0.0",
      description: "Plugin description",
      author: "Your Name",
      capabilities: [:ui_panel]
    }
  end

  defstruct [:config]

  @impl true
  def init(config), do: {:ok, %__MODULE__{config: config}}

  @impl true
  def enable(state), do: {:ok, state}

  @impl true
  def disable(state), do: {:ok, state}

  @impl true
  def terminate(_reason, _state), do: :ok
end
```
