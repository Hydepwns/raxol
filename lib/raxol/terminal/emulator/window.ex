defmodule Raxol.Terminal.Emulator.Window do
  @moduledoc """
  Handles window management for the terminal emulator.
  Provides functions for window state, manipulation, and properties.
  """

  require Logger

  alias Raxol.Terminal.Core

  @doc """
  Sets the window title.
  Returns {:ok, updated_emulator}.
  """
  @spec set_title(Core.t(), String.t()) :: {:ok, Core.t()}
  def set_title(%Core{} = emulator, title) when is_binary(title) do
    window_state = Map.put(emulator.window_state, :title, title)
    {:ok, %{emulator | window_title: title, window_state: window_state}}
  end

  def set_title(%Core{} = _emulator, invalid_title) do
    {:error, "Invalid window title: #{inspect(invalid_title)}"}
  end

  @doc """
  Sets the window icon name.
  Returns {:ok, updated_emulator}.
  """
  @spec set_icon_name(Core.t(), String.t()) :: {:ok, Core.t()}
  def set_icon_name(%Core{} = emulator, name) when is_binary(name) do
    window_state = Map.put(emulator.window_state, :icon_name, name)
    {:ok, %{emulator | icon_name: name, window_state: window_state}}
  end

  def set_icon_name(%Core{} = _emulator, invalid_name) do
    {:error, "Invalid icon name: #{inspect(invalid_name)}"}
  end

  @doc """
  Sets the window size.
  Returns {:ok, updated_emulator}.
  """
  @spec set_size(Core.t(), non_neg_integer(), non_neg_integer()) :: {:ok, Core.t()}
  def set_size(%Core{} = emulator, width, height) when width > 0 and height > 0 do
    window_state = Map.put(emulator.window_state, :size, {width, height})
    {:ok, %{emulator | width: width, height: height, window_state: window_state}}
  end

  def set_size(%Core{} = _emulator, width, height) do
    {:error, "Invalid window size: #{width}x#{height}"}
  end

  @doc """
  Sets the window position.
  Returns {:ok, updated_emulator}.
  """
  @spec set_position(Core.t(), non_neg_integer(), non_neg_integer()) :: {:ok, Core.t()}
  def set_position(%Core{} = emulator, x, y) when x >= 0 and y >= 0 do
    window_state = Map.put(emulator.window_state, :position, {x, y})
    {:ok, %{emulator | window_state: window_state}}
  end

  def set_position(%Core{} = _emulator, x, y) do
    {:error, "Invalid window position: (#{x}, #{y})"}
  end

  @doc """
  Sets the window stacking order.
  Returns {:ok, updated_emulator}.
  """
  @spec set_stacking_order(Core.t(), :normal | :maximized | :iconified) :: {:ok, Core.t()}
  def set_stacking_order(%Core{} = emulator, order) when order in [:normal, :maximized, :iconified] do
    window_state = Map.put(emulator.window_state, :stacking_order, order)
    {:ok, %{emulator | window_state: window_state}}
  end

  def set_stacking_order(%Core{} = _emulator, invalid_order) do
    {:error, "Invalid stacking order: #{inspect(invalid_order)}"}
  end

  @doc """
  Maximizes the window.
  Returns {:ok, updated_emulator}.
  """
  @spec maximize(Core.t()) :: {:ok, Core.t()}
  def maximize(%Core{} = emulator) do
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
  @spec restore(Core.t()) :: {:ok, Core.t()}
  def restore(%Core{} = emulator) do
    window_state = emulator.window_state
    case window_state.previous_size do
      nil ->
        {:error, "No previous size to restore"}
      {width, height} ->
        window_state = Map.put(window_state, :size, {width, height})
        window_state = Map.put(window_state, :maximized, false)
        window_state = Map.put(window_state, :stacking_order, :normal)
        window_state = Map.put(window_state, :previous_size, nil)

        {:ok, %{emulator | width: width, height: height, window_state: window_state}}
    end
  end

  @doc """
  Iconifies the window.
  Returns {:ok, updated_emulator}.
  """
  @spec iconify(Core.t()) :: {:ok, Core.t()}
  def iconify(%Core{} = emulator) do
    window_state = emulator.window_state
    window_state = Map.put(window_state, :iconified, true)
    window_state = Map.put(window_state, :stacking_order, :iconified)

    {:ok, %{emulator | window_state: window_state}}
  end

  @doc """
  Deiconifies the window.
  Returns {:ok, updated_emulator}.
  """
  @spec deiconify(Core.t()) :: {:ok, Core.t()}
  def deiconify(%Core{} = emulator) do
    window_state = emulator.window_state
    window_state = Map.put(window_state, :iconified, false)
    window_state = Map.put(window_state, :stacking_order, :normal)

    {:ok, %{emulator | window_state: window_state}}
  end

  @doc """
  Gets the current window state.
  Returns the window state.
  """
  @spec get_state(Core.t()) :: Core.window_state()
  def get_state(%Core{} = emulator) do
    emulator.window_state
  end
end
