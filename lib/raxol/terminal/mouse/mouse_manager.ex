defmodule Raxol.Terminal.Mouse.Manager do
  @moduledoc """
  Manages mouse events and tracking in the terminal, including button clicks,
  movement, and wheel events.
  """

  defstruct [
    :enabled,
    :mode,
    :button_state,
    :last_position,
    :tracking_enabled,
    :highlight_tracking,
    :cell_motion_tracking,
    :sgr_mode,
    :urxvt_mode,
    :pixel_position_tracking
  ]

  @type mouse_mode :: :normal | :button_event | :any_event | :highlight_tracking
  @type button_state ::
          :none | :left | :middle | :right | :wheel_up | :wheel_down
  @type position :: {non_neg_integer(), non_neg_integer()}

  @type t :: %__MODULE__{
          enabled: boolean(),
          mode: mouse_mode(),
          button_state: button_state(),
          last_position: position() | nil,
          tracking_enabled: boolean(),
          highlight_tracking: boolean(),
          cell_motion_tracking: boolean(),
          sgr_mode: boolean(),
          urxvt_mode: boolean(),
          pixel_position_tracking: boolean()
        }

  @doc """
  Creates a new mouse manager instance.
  """
  def new do
    %__MODULE__{
      enabled: false,
      mode: :normal,
      button_state: :none,
      last_position: nil,
      tracking_enabled: false,
      highlight_tracking: false,
      cell_motion_tracking: false,
      sgr_mode: false,
      urxvt_mode: false,
      pixel_position_tracking: false
    }
  end

  @doc """
  Enables mouse tracking.
  """
  def enable(%__MODULE__{} = manager) do
    %{manager | enabled: true}
  end

  @doc """
  Disables mouse tracking.
  """
  def disable(%__MODULE__{} = manager) do
    %{manager | enabled: false}
  end

  @doc """
  Checks if mouse tracking is enabled.
  """
  def enabled?(%__MODULE__{} = manager) do
    manager.enabled
  end

  @doc """
  Sets the mouse tracking mode.
  """
  def set_mode(%__MODULE__{} = manager, mode)
      when mode in [:normal, :button_event, :any_event, :highlight_tracking] do
    %{manager | mode: mode}
  end

  @doc """
  Gets the current mouse tracking mode.
  """
  def get_mode(%__MODULE__{} = manager) do
    manager.mode
  end

  @doc """
  Updates the button state.
  """
  def set_button_state(%__MODULE__{} = manager, state)
      when state in [:none, :left, :middle, :right, :wheel_up, :wheel_down] do
    %{manager | button_state: state}
  end

  @doc """
  Gets the current button state.
  """
  def get_button_state(%__MODULE__{} = manager) do
    manager.button_state
  end

  @doc """
  Updates the last known mouse position.
  """
  def set_position(%__MODULE__{} = manager, {x, y} = position)
      when is_integer(x) and is_integer(y) do
    %{manager | last_position: position}
  end

  @doc """
  Gets the last known mouse position.
  """
  def get_position(%__MODULE__{} = manager) do
    manager.last_position
  end

  @doc """
  Enables highlight tracking.
  """
  def enable_highlight_tracking(%__MODULE__{} = manager) do
    %{manager | highlight_tracking: true}
  end

  @doc """
  Disables highlight tracking.
  """
  def disable_highlight_tracking(%__MODULE__{} = manager) do
    %{manager | highlight_tracking: false}
  end

  @doc """
  Enables cell motion tracking.
  """
  def enable_cell_motion_tracking(%__MODULE__{} = manager) do
    %{manager | cell_motion_tracking: true}
  end

  @doc """
  Disables cell motion tracking.
  """
  def disable_cell_motion_tracking(%__MODULE__{} = manager) do
    %{manager | cell_motion_tracking: false}
  end

  @doc """
  Enables SGR mode.
  """
  def enable_sgr_mode(%__MODULE__{} = manager) do
    %{manager | sgr_mode: true}
  end

  @doc """
  Disables SGR mode.
  """
  def disable_sgr_mode(%__MODULE__{} = manager) do
    %{manager | sgr_mode: false}
  end

  @doc """
  Enables URXVT mode.
  """
  def enable_urxvt_mode(%__MODULE__{} = manager) do
    %{manager | urxvt_mode: true}
  end

  @doc """
  Disables URXVT mode.
  """
  def disable_urxvt_mode(%__MODULE__{} = manager) do
    %{manager | urxvt_mode: false}
  end

  @doc """
  Enables pixel position tracking.
  """
  def enable_pixel_position_tracking(%__MODULE__{} = manager) do
    %{manager | pixel_position_tracking: true}
  end

  @doc """
  Disables pixel position tracking.
  """
  def disable_pixel_position_tracking(%__MODULE__{} = manager) do
    %{manager | pixel_position_tracking: false}
  end

  @doc """
  Resets the mouse manager to its initial state.
  """
  def reset(%__MODULE__{} = _manager) do
    new()
  end
end
