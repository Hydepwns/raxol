defmodule Raxol.Terminal.Driver.Stty do
  @moduledoc false

  # Thin wrapper around `:os.cmd/1` for stty operations on /dev/tty.
  # All arguments are hardcoded charlists -- no user input is interpolated.
  # Centralizes the Credo.Check.Warning.UnsafeExec suppression to one place.

  @doc "Save current TTY settings (stty -g). Returns empty string on failure."
  @spec save :: String.t()
  def save do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeExec
    :os.cmd(~c"stty -g < /dev/tty 2>/dev/null")
    |> List.to_string()
    |> String.trim()
  end

  @doc "Enter raw mode: no echo, no line buffering, no signals."
  @spec raw! :: :ok
  def raw! do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeExec
    _ = :os.cmd(~c"stty raw -echo -icanon -isig < /dev/tty 2>/dev/null")
    :ok
  end

  @doc "Restore previously saved TTY settings, or fall back to `stty sane`."
  @spec restore(String.t() | nil) :: :ok
  def restore(saved) when is_binary(saved) and byte_size(saved) > 0 do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeExec
    _ = :os.cmd(String.to_charlist("stty #{saved} < /dev/tty 2>/dev/null"))
    :ok
  end

  def restore(_), do: sane!()

  @doc "Reset TTY to sane defaults."
  @spec sane! :: :ok
  def sane! do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeExec
    _ = :os.cmd(~c"stty sane < /dev/tty 2>/dev/null")
    :ok
  end

  @doc "Query terminal size via `stty size`. Returns `{:ok, cols, rows}` or `:error`."
  @spec size :: {:ok, pos_integer(), pos_integer()} | :error
  def size do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeExec
    result = :os.cmd(~c"stty size < /dev/tty 2>/dev/null")
    str = result |> List.to_string() |> String.trim()

    case String.split(str) do
      [rows_s, cols_s] ->
        rows = String.to_integer(rows_s)
        cols = String.to_integer(cols_s)
        if rows > 0 and cols > 0, do: {:ok, cols, rows}, else: :error

      _ ->
        :error
    end
  end
end
