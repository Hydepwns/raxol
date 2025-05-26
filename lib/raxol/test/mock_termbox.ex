defmodule Raxol.Test.MockTermbox do
  @moduledoc """
  Mock implementation of rrex_termbox v2.0.1 for testing environments.

  This module provides stub implementations of all rrex_termbox NIF-based functions
  to allow tests to run in CI environments where a real TTY may not be available.
  """

  require Raxol.Core.Runtime.Log

  # NIF interface
  def start_link do
    Raxol.Core.Runtime.Log.debug("MockTermbox: start_link called")
    {:ok, :mock_pid}
  end

  def subscribe do
    Raxol.Core.Runtime.Log.debug("MockTermbox: subscribe called")
    :ok
  end

  def unsubscribe do
    Raxol.Core.Runtime.Log.debug("MockTermbox: unsubscribe called")
    :ok
  end

  def size do
    Raxol.Core.Runtime.Log.debug("MockTermbox: size called")
    {:ok, 80, 24}
  end

  @spec init(opts :: keyword()) :: {:ok, pid()}
  def init(opts \\ []) do
    owner = Keyword.get(opts, :owner, self())
    Raxol.Core.Runtime.Log.debug("MockTermbox: init called with owner: #{inspect(owner)}")
    {:ok, self()}
  end

  def shutdown(_server \\ nil) do
    Raxol.Core.Runtime.Log.debug("MockTermbox: shutdown called")
    :ok
  end

  def clear(_server \\ nil) do
    Raxol.Core.Runtime.Log.debug("MockTermbox: clear called")
    :ok
  end

  def present(_server \\ nil) do
    Raxol.Core.Runtime.Log.debug("MockTermbox: present called")
    :ok
  end

  def width(_server \\ nil) do
    Raxol.Core.Runtime.Log.debug("MockTermbox: width called")
    {:ok, 80}
  end

  def height(_server \\ nil) do
    Raxol.Core.Runtime.Log.debug("MockTermbox: height called")
    {:ok, 24}
  end

  def select_input_mode(_mode, _server \\ nil) do
    Raxol.Core.Runtime.Log.debug("MockTermbox: select_input_mode called")
    {:ok, 1}
  end

  def set_output_mode(_mode, _server \\ nil) do
    Raxol.Core.Runtime.Log.debug("MockTermbox: set_output_mode called")
    {:ok, 1}
  end

  def set_cursor(_x \\ 0, _y \\ 0, _server \\ nil) do
    Raxol.Core.Runtime.Log.debug("MockTermbox: set_cursor called")
    :ok
  end

  def change_cell(_x, _y, _ch, _fg, _bg, _server \\ nil) do
    Raxol.Core.Runtime.Log.debug("MockTermbox: change_cell called")
    :ok
  end

  def set_cell(_x, _y, _ch, _fg, _bg) do
    Raxol.Core.Runtime.Log.debug("MockTermbox: set_cell called")
    :ok
  end

  # Constants module
  defmodule Constants do
    def attribute(_name) do
      # Placeholder
      0
    end

    def color(_name) do
      # Placeholder
      0
    end

    def key(_name) do
      # Placeholder
      0
    end

    def event_type(_name) do
      # Placeholder
      0
    end
  end
end
