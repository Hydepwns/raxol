defmodule EventHandler do
  @moduledoc """
  Root-level EventHandler module that delegates to the unified event system.
  Provides backward compatibility for existing code.
  """

  defdelegate handle_input(manager, input), to: Raxol.Events.EventServer

  defdelegate handle_output(manager, output),
    to: Raxol.Events.EventServer

  defdelegate handle_resize(manager, width, height),
    to: Raxol.Events.EventServer
end
