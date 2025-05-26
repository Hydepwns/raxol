defmodule Raxol.Terminal.Emulator.Window do
  @moduledoc """
  Handles window management for the terminal emulator.
  Provides functions for window state, manipulation, and properties.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator

  @doc """
  Sets the window title.
  Returns {:ok, updated_emulator}.
  """
  @spec set_title(Emulator.t(), String.t()) :: {:ok, Emulator.t()}
  def set_title(%Emulator{} = emulator, title) when is_binary(title) do
    window_state = Map.put(emulator.window_state, :title, title)
    {:ok, %{emulator | window_title: title, window_state: window_state}}
  end

  def set_title(%Emulator{} = _emulator, invalid_title) do
    {:error, "Invalid window title: #{inspect(invalid_title)}"}
  end

  @doc """
  Sets the window icon name.
  Returns {:ok, updated_emulator}.
  """
  @spec set_icon_name(Emulator.t(), String.t()) :: {:ok, Emulator.t()}
  def set_icon_name(%Emulator{} = emulator, name) when is_binary(name) do
    window_state = Map.put(emulator.window_state, :icon_name, name)
    {:ok, %{emulator | icon_name: name, window_state: window_state}}
  end

  def set_icon_name(%Emulator{} = _emulator, invalid_name) do
    {:error, "Invalid icon name: #{inspect(invalid_name)}"}
  end

  @doc """
  Sets the window size.
  Returns {:ok, updated_emulator}.
  """
  @spec set_size(Emulator.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, Emulator.t()}
  def set_size(%Emulator{} = emulator, width, height)
      when width > 0 and height > 0 do
    window_state = Map.put(emulator.window_state, :size, {width, height})

    {:ok,
     %{emulator | width: width, height: height, window_state: window_state}}
  end

  def set_size(%Emulator{} = _emulator, width, height) do
    {:error, "Invalid window size: #{width}x#{height}"}
  end

  @doc """
  Sets the window position.
  Returns {:ok, updated_emulator}.
  """
  @spec set_position(Emulator.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, Emulator.t()}
  def set_position(%Emulator{} = emulator, x, y) when x >= 0 and y >= 0 do
    window_state = Map.put(emulator.window_state, :position, {x, y})
    {:ok, %{emulator | window_state: window_state}}
  end

  def set_position(%Emulator{} = _emulator, x, y) do
    {:error, "Invalid window position: (#{x}, #{y})"}
  end

  @doc """
  Sets the window stacking order.
  Returns {:ok, updated_emulator}.
  """
  @spec set_stacking_order(Emulator.t(), :normal | :maximized | :iconified) ::
          {:ok, Emulator.t()}
  def set_stacking_order(%Emulator{} = emulator, order)
      when order in [:normal, :maximized, :iconified] do
    window_state = Map.put(emulator.window_state, :stacking_order, order)
    {:ok, %{emulator | window_state: window_state}}
  end

  def set_stacking_order(%Emulator{} = _emulator, invalid_order) do
    {:error, "Invalid stacking order: #{inspect(invalid_order)}"}
  end

  @doc """
  Maximizes the window.
  Returns {:ok, updated_emulator}.
  """
  @spec maximize(Emulator.t()) :: {:ok, Emulator.t()}
  def maximize(%Emulator{} = emulator) do
    # Store current size before maximizing
    window_state = emulator.window_state
    window_state = Map.put(window_state, :previous_size, window_state.size)
    window_state = Map.put(window_state, :maximized, true)
    window_state = Map.put(window_state, :stacking_order, :maximized)

    {:ok, %{emulator | window_state: window_state}}
  end

  @doc """
  Restores the window from maximized state.
  Returns {:ok, updated_emulator}.
  """
  @spec restore(Emulator.t()) :: {:ok, Emulator.t()}
  def restore(%Emulator{} = emulator) do
    window_state = emulator.window_state

    case window_state.previous_size do
      nil ->
        {:error, "No previous size to restore"}

      {width, height} ->
        window_state = Map.put(window_state, :size, {width, height})
        window_state = Map.put(window_state, :maximized, false)
        window_state = Map.put(window_state, :stacking_order, :normal)
        window_state = Map.put(window_state, :previous_size, nil)

        {:ok,
         %{emulator | width: width, height: height, window_state: window_state}}
    end
  end

  @doc """
  Iconifies the window.
  Returns {:ok, updated_emulator}.
  """
  @spec iconify(Emulator.t()) :: {:ok, Emulator.t()}
  def iconify(%Emulator{} = emulator) do
    window_state = emulator.window_state
    window_state = Map.put(window_state, :iconified, true)
    window_state = Map.put(window_state, :stacking_order, :iconified)

    {:ok, %{emulator | window_state: window_state}}
  end

  @doc """
  Deiconifies the window.
  Returns {:ok, updated_emulator}.
  """
  @spec deiconify(Emulator.t()) :: {:ok, Emulator.t()}
  def deiconify(%Emulator{} = emulator) do
    window_state = emulator.window_state
    window_state = Map.put(window_state, :iconified, false)
    window_state = Map.put(window_state, :stacking_order, :normal)

    {:ok, %{emulator | window_state: window_state}}
  end

  @doc """
  Gets the current window state.
  Returns the window state.
  """
  @spec get_state(Emulator.t()) :: map()
  def get_state(%Emulator{} = emulator) do
    emulator.window_state
  end
end
