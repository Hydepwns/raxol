unless Code.ensure_loaded?(Raxol.Test.IsolationHelper) do
  defmodule Raxol.Test.IsolationHelper do
    @moduledoc false
    # Minimal stub for tests that need global state reset.
    def reset_global_state, do: :ok
  end
end
