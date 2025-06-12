defmodule Raxol.Terminal.Window.Manager do
  @moduledoc """
  Manages window-related operations for the terminal emulator.
  This module handles window creation, destruction, switching, and state management.
  """

  alias Raxol.Terminal.{Window, Window.Registry, Cursor, Screen}

  @window_commands %{
    1 => {:handle_deiconify, 0},
    2 => {:handle_iconify, 0},
    3 => {:handle_move, 2},
    4 => {:handle_resize, 2},
    5 => {:handle_raise, 0},
    6 => {:handle_lower, 0},
    7 => {:refresh_window, 0},
    9 => {:handle_restore_maximize, 1}
  }

  @doc """
  Creates a new window.
  """
  @spec create_window(Window.Config.t()) :: {:ok, Window.t()} | {:error, term()}
  def create_window(config) do
    window = Window.new(config)
    Registry.register_window(window)
  end

  @doc """
  Creates a new window with custom dimensions.
  """
  @spec create_window(non_neg_integer(), non_neg_integer()) :: {:ok, Window.t()} | {:error, term()}
  def create_window(width, height) do
    window = Window.new(width, height)
    Registry.register_window(window)
  end

  @doc """
  Destroys a window.
  """
  @spec destroy_window(String.t()) :: :ok | {:error, term()}
  def destroy_window(window_id) do
    Registry.unregister_window(window_id)
  end

  @doc """
  Gets a window by ID.
  """
  @spec get_window(String.t()) :: {:ok, Window.t()} | {:error, term()}
  def get_window(window_id) do
    Registry.get_window(window_id)
  end

  @doc """
  Lists all windows.
  """
  @spec list_windows() :: {:ok, [Window.t()]}
  def list_windows do
    Registry.list_windows()
  end

  @doc """
  Gets the active window.
  """
  @spec get_active_window() :: {:ok, Window.t()} | {:error, term()}
  def get_active_window do
    Registry.get_active_window()
  end

  @doc """
  Sets the active window.
  """
  @spec set_active_window(String.t()) :: :ok | {:error, term()}
  def set_active_window(window_id) do
    Registry.set_active_window(window_id)
  end

  @doc """
  Updates a window's title.
  """
  @spec set_window_title(String.t(), String.t()) :: {:ok, Window.t()} | {:error, term()}
  def set_window_title(window_id, title) do
    with {:ok, window} <- Registry.get_window(window_id) do
      updated_window = Window.set_title(window, title)
      Registry.update_window(window_id, updated_window)
    end
  end

  @doc """
  Updates a window's position.
  """
  @spec set_window_position(String.t(), integer(), integer()) :: {:ok, Window.t()} | {:error, term()}
  def set_window_position(window_id, x, y) do
    with {:ok, window} <- Registry.get_window(window_id) do
      updated_window = Window.set_position(window, x, y)
      Registry.update_window(window_id, updated_window)
    end
  end

  @doc """
  Updates a window's size.
  """
  @spec set_window_size(String.t(), non_neg_integer(), non_neg_integer()) :: {:ok, Window.t()} | {:error, term()}
  def set_window_size(window_id, width, height) do
    with {:ok, window} <- Registry.get_window(window_id) do
      updated_window = Window.set_size(window, width, height)
      Registry.update_window(window_id, updated_window)
    end
  end

  @doc """
  Updates a window's state.
  """
  @spec set_window_state(String.t(), Window.window_state()) :: {:ok, Window.t()} | {:error, term()}
  def set_window_state(window_id, state) do
    with {:ok, window} <- Registry.get_window(window_id) do
      updated_window = Window.set_state(window, state)
      Registry.update_window(window_id, updated_window)
    end
  end

  @doc """
  Creates a child window.
  """
  @spec create_child_window(String.t(), Window.Config.t()) :: {:ok, Window.t()} | {:error, term()}
  def create_child_window(parent_id, config) do
    with {:ok, parent} <- Registry.get_window(parent_id),
         {:ok, child} <- create_window(config) do
      # Update parent-child relationship
      updated_parent = Window.add_child(parent, child.id)
      updated_child = Window.set_parent(child, parent_id)

      Registry.update_window(parent_id, updated_parent)
      Registry.update_window(child.id, updated_child)

      {:ok, child}
    end
  end

  @doc """
  Gets all child windows of a window.
  """
  @spec get_child_windows(String.t()) :: {:ok, [Window.t()]} | {:error, term()}
  def get_child_windows(window_id) do
    with {:ok, window} <- Registry.get_window(window_id) do
      child_ids = Window.get_children(window)
      children = Enum.map(child_ids, &Registry.get_window/1)
      {:ok, Enum.map(children, fn {:ok, child} -> child end)}
    end
  end

  @doc """
  Gets the parent window of a window.
  """
  @spec get_parent_window(String.t()) :: {:ok, Window.t()} | {:error, term()}
  def get_parent_window(window_id) do
    with {:ok, window} <- Registry.get_window(window_id),
         parent_id when not is_nil(parent_id) <- Window.get_parent(window) do
      Registry.get_window(parent_id)
    else
      nil -> {:error, :no_parent}
      error -> error
    end
  end

  @doc """
  Handles window manipulation commands.
  """
  def handle_window_command(emulator, params) do
    case params do
      [cmd | args] ->
        case @window_commands[cmd] do
          {handler, arity} when length(args) == arity ->
            apply(__MODULE__, handler, [emulator | args])
          _ -> {:ok, emulator}
        end
      _ -> {:ok, emulator}
    end
  end

  defp handle_restore_maximize(emulator, 0), do: restore_window(emulator)
  defp handle_restore_maximize(emulator, 1), do: maximize_window(emulator)
  defp handle_restore_maximize(emulator, _), do: {:ok, emulator}

  defp handle_deiconify(emulator) do
    {:ok, %{emulator | window_state: %{emulator.window_state | iconified: false}}}
  end

  defp handle_iconify(emulator) do
    {:ok, %{emulator | window_state: %{emulator.window_state | iconified: true}}}
  end

  defp handle_move(emulator, x, y) do
    {:ok, %{emulator | window_state: %{emulator.window_state | position: {x, y}}}}
  end

  defp handle_resize(emulator, width, height) do
    {:ok, %{emulator |
      window_state: %{emulator.window_state | size: {width, height}},
      width: width,
      height: height
    }}
  end

  defp handle_raise(emulator) do
    {:ok, %{emulator | window_state: %{emulator.window_state | stacking_order: :normal}}}
  end

  defp handle_lower(emulator) do
    {:ok, %{emulator | window_state: %{emulator.window_state | stacking_order: :lowered}}}
  end

  @doc """
  Refreshes the window by marking the entire screen as damaged and updating cursor state.
  """
  def refresh_window(emulator) do
    # Mark entire screen as damaged for redraw
    emulator = %{emulator |
      window_state: %{emulator.window_state |
        needs_refresh: true,
        last_refresh: System.monotonic_time()
      }
    }

    # Force a full redraw of the screen
    emulator = case emulator.active_buffer_type do
      :main ->
        Screen.mark_damaged(emulator.main_screen_buffer, 0, 0, emulator.width, emulator.height)
        %{emulator | main_screen_buffer: emulator.main_screen_buffer}
      :alternate ->
        Screen.mark_damaged(emulator.alternate_screen_buffer, 0, 0, emulator.width, emulator.height)
        %{emulator | alternate_screen_buffer: emulator.alternate_screen_buffer}
    end

    # Update cursor visibility and position
    emulator = %{emulator |
      cursor: Cursor.set_visible(emulator.cursor, true),
      window_state: %{emulator.window_state |
        cursor_visible: true,
        cursor_blink: true,
        cursor_blink_time: System.monotonic_time()
      }
    }

    {:ok, emulator}
  end

  @doc """
  Restores the window to its previous size.
  """
  def restore_window(emulator) do
    case emulator.window_state.previous_size do
      nil -> {:ok, emulator}
      {width, height} ->
        {:ok, %{emulator |
          window_state: %{emulator.window_state |
            size: {width, height},
            previous_size: nil
          },
          width: width,
          height: height
        }}
    end
  end

  @doc """
  Maximizes the window and saves the previous size.
  """
  def maximize_window(emulator) do
    {:ok, %{emulator |
      window_state: %{emulator.window_state |
        previous_size: emulator.window_state.size,
        size: {emulator.width, emulator.height},
        maximized: true
      }
    }}
  end
end
