defmodule Raxol.Core.Runtime.Rendering.Engine.Behaviour do
  @moduledoc "Behaviour for Rendering.Engine, used for mocking."

  @callback start_link(initial_state_map :: map()) :: GenServer.on_start()
  # @callback handle_cast(:render_frame, map()) :: {:noreply, map()}
  # Add other callbacks as needed for tests
end
