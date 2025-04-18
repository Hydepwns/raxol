defmodule Raxol.Test.MockTermbox do
  @moduledoc """
  Mock implementation of ExTermbox.Bindings for testing environments.

  This module provides stub implementations of all ExTermbox functions
  to allow tests to run in CI environments where a real TTY may not be available.
  """

  require Logger

  def init do
    Logger.debug("MockTermbox: init called")
    {:ok, :ok}
  end

  def shutdown do
    Logger.debug("MockTermbox: shutdown called")
    :ok
  end

  def clear do
    Logger.debug("MockTermbox: clear called")
    :ok
  end

  def present do
    Logger.debug("MockTermbox: present called")
    :ok
  end

  def width do
    Logger.debug("MockTermbox: width called")
    {:ok, 80}
  end

  def height do
    Logger.debug("MockTermbox: height called")
    {:ok, 24}
  end

  def select_input_mode(_mode) do
    Logger.debug("MockTermbox: select_input_mode called")
    {:ok, 1}
  end

  def select_output_mode(_mode) do
    Logger.debug("MockTermbox: select_output_mode called")
    {:ok, 1}
  end

  def set_cursor(_x, _y) do
    Logger.debug("MockTermbox: set_cursor called")
    :ok
  end

  def set_cell(_x, _y, _ch, _fg, _bg) do
    Logger.debug("MockTermbox: set_cell called")
    :ok
  end

  def start_polling(_pid) do
    Logger.debug("MockTermbox: start_polling called")
    {:ok, make_ref()}
  end

  def stop_polling do
    Logger.debug("MockTermbox: stop_polling called")
    :ok
  end

  def change_cell(_x, _y, _ch, _fg, _bg) do
    Logger.debug("MockTermbox: change_cell called")
    :ok
  end
end
