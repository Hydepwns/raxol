defmodule Raxol.Test.ClipboardAssertions do
  @moduledoc """
  Provides assertion helpers for clipboard-related tests.
  """

  import ExUnit.Assertions

  @doc """
  Asserts that a clipboard write command was sent with the given content.
  """
  def assert_clipboard_write_command(content) do
    receive do
      {:command, :clipboard_write, [received_content]} ->
        assert received_content == content
    after
      1000 ->
        flunk(
          "Expected clipboard write command with content #{inspect(content)}"
        )
    end
  end

  @doc """
  Asserts that a clipboard read command was sent.
  """
  def assert_clipboard_read_command do
    assert_receive {:command, :clipboard_read, []}
  end
end
