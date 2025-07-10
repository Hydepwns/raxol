defmodule Raxol.Test.ClipboardAssertions do
  @moduledoc """
  Provides assertion helpers for clipboard-related tests.
  """

  import ExUnit.Assertions
  import Mox

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

  @doc """
  Sets up expectation for clipboard copy operation.
  """
  def expect_clipboard_copy(mock, content, result) do
    expect(mock, :copy, fn ^content -> result end)
  end

  @doc """
  Sets up expectation for clipboard paste operation.
  """
  def expect_clipboard_paste(mock, result) do
    expect(mock, :paste, fn -> result end)
  end

  @doc """
  Sets up expectation for clipboard paste error.
  """
  def expect_clipboard_paste_error(mock) do
    expect(mock, :paste, fn -> {:error, :error} end)
  end
end
