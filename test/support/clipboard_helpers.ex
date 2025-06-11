defmodule Raxol.Test.Support.ClipboardHelpers do
  @moduledoc """
  Helper functions for clipboard-related tests in Raxol.
  """

  import Mox
  import ExUnit.Assertions

  @doc """
  Creates a MultiLineInput state with the given content and cursor position.
  """
  def create_ml_state(content, opts \\ %{}) do
    %{content: content, opts: opts}
  end

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
  Expects a clipboard copy operation with the given content.
  """
  def expect_clipboard_copy(mock, content, result) do
    expect(mock, :copy, fn ^content -> result end)
  end

  @doc """
  Expects a clipboard paste operation that returns the given content.
  """
  def expect_clipboard_paste(mock, result) do
    expect(mock, :paste, fn -> result end)
  end

  @doc """
  Expects a clipboard paste operation that returns an error.
  """
  def expect_clipboard_paste_error do
    expect(ClipboardMock, :paste, fn -> {:error, :error} end)
  end
end
