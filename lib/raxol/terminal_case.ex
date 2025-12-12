defmodule Raxol.TerminalCase do
  @moduledoc """
  Test case helper for terminal-related tests.

  Provides helper functions for creating test terminals, sending input,
  and asserting on terminal output.

  ## Example

      defmodule MyTerminalTest do
        use Raxol.TerminalCase

        test "renders output correctly" do
          {:ok, term} = create_test_terminal(width: 80, height: 24)

          send_keys(term, "hello world")
          send_key(term, :enter)

          assert screen_text(term) =~ "hello world"
        end
      end
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Raxol.TerminalCase
    end
  end

  setup _tags do
    {:ok, %{}}
  end

  @doc """
  Create a test terminal emulator.

  ## Options

    - `:width` - Terminal width (default: 80)
    - `:height` - Terminal height (default: 24)

  ## Example

      {:ok, term} = create_test_terminal(width: 120, height: 40)
  """
  def create_test_terminal(opts \\ []) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)

    emulator = Raxol.Terminal.Emulator.new(width, height)
    {:ok, emulator}
  end

  @doc """
  Send a sequence of characters to the terminal.
  """
  def send_keys(term, keys) when is_binary(keys) do
    Raxol.Terminal.Emulator.process_input(term, keys)
  end

  @doc """
  Send a special key to the terminal.

  Supported keys: :enter, :tab, :backspace, :delete, :escape,
  :arrow_up, :arrow_down, :arrow_left, :arrow_right,
  :home, :end, :page_up, :page_down
  """
  def send_key(term, key) do
    sequence = key_to_sequence(key)
    Raxol.Terminal.Emulator.process_input(term, sequence)
  end

  @doc """
  Write raw ANSI sequences to the terminal.
  """
  def write_ansi(term, ansi) when is_binary(ansi) do
    Raxol.Terminal.Emulator.process_input(term, ansi)
  end

  @doc """
  Get the current screen text content.
  """
  def screen_text(term) do
    term
    |> get_buffer()
    |> buffer_to_text()
  end

  @doc """
  Get the current cursor position as {row, col}.
  """
  def cursor_position(term) do
    Raxol.Terminal.Emulator.get_cursor_position(term)
  end

  @doc """
  Get a cell at a specific position.
  """
  def cell_at(term, row, col) do
    buffer = get_buffer(term)
    Raxol.Terminal.ScreenBuffer.get_cell(buffer, row, col)
  end

  # Private helpers

  defp key_to_sequence(:enter), do: "\r"
  defp key_to_sequence(:tab), do: "\t"
  defp key_to_sequence(:backspace), do: "\b"
  defp key_to_sequence(:delete), do: "\e[3~"
  defp key_to_sequence(:escape), do: "\e"
  defp key_to_sequence(:arrow_up), do: "\e[A"
  defp key_to_sequence(:arrow_down), do: "\e[B"
  defp key_to_sequence(:arrow_right), do: "\e[C"
  defp key_to_sequence(:arrow_left), do: "\e[D"
  defp key_to_sequence(:home), do: "\e[H"
  defp key_to_sequence(:end), do: "\e[F"
  defp key_to_sequence(:page_up), do: "\e[5~"
  defp key_to_sequence(:page_down), do: "\e[6~"
  defp key_to_sequence(char) when is_binary(char), do: char

  defp get_buffer(term) do
    term.main_screen_buffer
  end

  defp buffer_to_text(buffer) do
    buffer.lines
    |> Enum.map(fn line ->
      line.cells
      |> Enum.map(& &1.char)
      |> Enum.join()
      |> String.trim_trailing()
    end)
    |> Enum.join("\n")
    |> String.trim()
  end
end
