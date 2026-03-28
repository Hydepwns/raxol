unless Code.ensure_loaded?(Raxol.Plugins.Plugin) do
  defmodule Raxol.Plugins.Plugin do
    @moduledoc false
    # Minimal stub for test fixtures that reference %Raxol.Plugins.Plugin{}.
    # Only compiled when the full raxol package is not available.
    defstruct [
      :name,
      :version,
      :description,
      :enabled,
      :config,
      :dependencies,
      :api_version,
      :module,
      :state
    ]
  end
end
