defmodule Raxol.Test.ClipboardHelpers do
  @moduledoc """
  Canonical test helpers for clipboard-related tests in Raxol.
  Provides utilities for state creation, clipboard command assertions, and Mox setup.
  """

  import ExUnit.Assertions

  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.TextHelper
  alias Raxol.Core.Runtime.Command

  @doc """
  Creates a MultiLineInput state for clipboard tests.
  """
  def create_state(value \\ "", cursor_pos \\ {0, 0}, selection \\ nil) do
    sel_start = if selection, do: elem(selection, 0), else: nil
    sel_end = if selection, do: elem(selection, 1), else: nil
    lines = TextHelper.split_into_lines(value, 40, :word)

    %MultiLineInput{
      value: value,
      lines: lines,
      cursor_pos: cursor_pos,
      selection_start: sel_start,
      selection_end: sel_end,
      id: "test_input",
      width: 40,
      height: 10,
      wrap: :word,
      scroll_offset: {0, 0},
      history: nil
    }
  end

  @doc """
  Asserts that the clipboard write command is present in the command list with the expected content.
  """
  def assert_clipboard_write(commands, expected_content) do
    expected_cmd = Command.clipboard_write(expected_content)
    assert [^expected_cmd] = commands
  end

  @doc """
  Asserts that the clipboard read command is present in the command list.
  """
  def assert_clipboard_read(commands) do
    expected_cmd = Command.clipboard_read()
    assert [^expected_cmd] = commands
  end

  @doc """
  Sets up Mox expectations for clipboard copy and paste.
  """
  def expect_clipboard_copy(mock, content, return_value \\ :ok) do
    Mox.expect(mock, :copy, fn ^content -> return_value end)
  end

  def expect_clipboard_paste(mock, return_value) do
    Mox.expect(mock, :paste, fn -> return_value end)
  end
end
