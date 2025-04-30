defmodule Raxol.Test.MockTermbox do
  @moduledoc """
  Mock implementation of rrex_termbox v2.0.1 for testing environments.

  This module provides stub implementations of all rrex_termbox NIF-based functions
  to allow tests to run in CI environments where a real TTY may not be available.
  """

  require Logger

  # NIF interface
  def start_link do
    Logger.debug("MockTermbox: start_link called")
    {:ok, :mock_pid}
  end

  def subscribe do
    Logger.debug("MockTermbox: subscribe called")
    :ok
  end

  def unsubscribe do
    Logger.debug("MockTermbox: unsubscribe called")
    :ok
  end

  def size do
    Logger.debug("MockTermbox: size called")
    {:ok, 80, 24}
  end

  def init(opts \\ []) do
    owner = Keyword.get(opts, :owner, self())
    Logger.debug("MockTermbox: init called with owner: #{inspect(owner)}")
    {:ok, self()}
  end

  def shutdown(_server \\ nil) do
    Logger.debug("MockTermbox: shutdown called")
    :ok
  end

  def clear(_server \\ nil) do
    Logger.debug("MockTermbox: clear called")
    :ok
  end

  def present(_server \\ nil) do
    Logger.debug("MockTermbox: present called")
    :ok
  end

  def width(_server \\ nil) do
    Logger.debug("MockTermbox: width called")
    {:ok, 80}
  end

  def height(_server \\ nil) do
    Logger.debug("MockTermbox: height called")
    {:ok, 24}
  end

  def select_input_mode(_mode, _server \\ nil) do
    Logger.debug("MockTermbox: select_input_mode called")
    {:ok, 1}
  end

  def set_output_mode(_mode, _server \\ nil) do
    Logger.debug("MockTermbox: set_output_mode called")
    {:ok, 1}
  end

  def set_cursor(_x \\ 0, _y \\ 0, _server \\ nil) do
    Logger.debug("MockTermbox: set_cursor called")
    :ok
  end

  def change_cell(_x, _y, _ch, _fg, _bg, _server \\ nil) do
    Logger.debug("MockTermbox: change_cell called")
    :ok
  end

  def set_cell(_x, _y, _ch, _fg, _bg) do
    Logger.debug("MockTermbox: set_cell called")
    :ok
  end

  # Constants module
  defmodule Constants do
    def attribute(_name) do
      0 # Placeholder
    end

    def color(_name) do
      0 # Placeholder
    end

    def key(_name) do
      0 # Placeholder
    end

    def event_type(_name) do
      0 # Placeholder
    end
  end
end
