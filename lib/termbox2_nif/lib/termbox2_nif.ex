defmodule :termbox2_nif do
  @moduledoc """
  Termbox2 NIF for Elixir - A terminal UI library.
  """

  @on_load :load_nif

  def load_nif do
    priv_dir = :code.priv_dir(:termbox2_nif)
    nif_path = Path.join(priv_dir, "termbox2_nif")

    case :erlang.load_nif(nif_path, 0) do
      :ok -> :ok
      {:error, reason} ->
        IO.puts("Failed to load Termbox2 NIF: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Initialize the termbox2 library.
  Returns 0 on success, -1 on error.
  """
  def tb_init, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Shutdown the termbox2 library.
  """
  def tb_shutdown, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Get the width of the terminal.
  """
  def tb_width, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Get the height of the terminal.
  """
  def tb_height, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Clear the terminal.
  """
  def tb_clear, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Present the changes to the terminal.
  """
  def tb_present, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Set the cursor position.
  """
  def tb_set_cursor(_x, _y), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Hide the cursor.
  Returns 0 on success, -1 on error.
  """
  def tb_hide_cursor, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Set a cell in the terminal.
  Returns 0 on success, -1 on error.
  """
  def tb_set_cell(_x, _y, _ch, _fg, _bg), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Set the input mode.
  Returns the previous mode.
  """
  def tb_set_input_mode(_mode), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Set the output mode.
  Returns the previous mode.
  """
  def tb_set_output_mode(_mode), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Print a string at the specified position.
  Returns 0 on success, -1 on error.
  """
  def tb_print(_x, _y, _fg, _bg, _str), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Set the terminal title.
  Returns {:ok, "set"} on success, {:error, reason} on failure.
  """
  def tb_set_title(_title), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Set the terminal window position.
  Returns {:ok, "set"} on success, {:error, reason} on failure.
  """
  def tb_set_position(_x, _y), do: :erlang.nif_error(:nif_not_loaded)
end
