defmodule Raxol.System.InteractionImpl do
  @moduledoc '''
  Concrete implementation of the System.Interaction behaviour using standard Elixir/Erlang functions.
  '''
  @behaviour Raxol.System.Interaction

  @impl Raxol.System.Interaction
  def get_os_type do
    :os.type()
  end

  @impl Raxol.System.Interaction
  def find_executable(name) do
    System.find_executable(name)
  end

  @impl Raxol.System.Interaction
  def system_cmd(command, args, opts) do
    # System.cmd returns {output, status_code}
    System.cmd(command, args, opts)
  end
end
