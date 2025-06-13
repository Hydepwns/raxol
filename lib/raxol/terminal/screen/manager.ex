defmodule Raxol.Terminal.ScreenManager do
  @moduledoc """
  Manages screen buffer operations for the terminal emulator.
  This module handles operations related to the main and alternate screen buffers,
  including buffer switching, initialization, and state management.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Manager
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  @doc """
  Gets the currently active screen buffer.
  """
  @spec get_active_buffer(EmulatorStruct.t()) :: ScreenBuffer.t()
  def get_active_buffer(%{active_buffer_type: :main} = emulator) do
    emulator.main_screen_buffer
  end

  def get_active_buffer(%{active_buffer_type: :alternate} = emulator) do
    emulator.alternate_screen_buffer
  end

  @doc """
  Updates the currently active screen buffer.
  """
  @spec update_active_buffer(EmulatorStruct.t(), ScreenBuffer.t()) :: EmulatorStruct.t()
  def update_active_buffer(%{active_buffer_type: :main} = emulator, new_buffer) do
    %{emulator | main_screen_buffer: new_buffer}
  end

  def update_active_buffer(%{active_buffer_type: :alternate} = emulator, new_buffer) do
    %{emulator | alternate_screen_buffer: new_buffer}
  end

  @doc """
  Switches between main and alternate screen buffers.
  """
  @spec switch_buffer(EmulatorStruct.t()) :: EmulatorStruct.t()
  def switch_buffer(emulator) do
    new_type = if emulator.active_buffer_type == :main, do: :alternate, else: :main
    %{emulator | active_buffer_type: new_type}
  end

  @doc """
  Initializes both main and alternate screen buffers.
  """
  @spec initialize_buffers(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: {ScreenBuffer.t(), ScreenBuffer.t()}
  def initialize_buffers(width, height, scrollback_limit) do
    Manager.initialize_buffers(width, height, scrollback_limit)
  end

  @doc """
  Resizes both screen buffers.
  """
  @spec resize_buffers(EmulatorStruct.t(), non_neg_integer(), non_neg_integer()) :: EmulatorStruct.t()
  def resize_buffers(emulator, new_width, new_height) do
    new_main_buffer = ScreenBuffer.resize(emulator.main_screen_buffer, new_width, new_height)
    new_alt_buffer = ScreenBuffer.resize(emulator.alternate_screen_buffer, new_width, new_height)

    %{emulator |
      main_screen_buffer: new_main_buffer,
      alternate_screen_buffer: new_alt_buffer,
      width: new_width,
      height: new_height
    }
  end

  @doc """
  Gets the current buffer type (main or alternate).
  """
  @spec get_buffer_type(EmulatorStruct.t()) :: :main | :alternate
  def get_buffer_type(emulator) do
    emulator.active_buffer_type
  end

  @doc """
  Sets the buffer type.
  """
  @spec set_buffer_type(EmulatorStruct.t(), :main | :alternate) :: EmulatorStruct.t()
  def set_buffer_type(emulator, type) when type in [:main, :alternate] do
    %{emulator | active_buffer_type: type}
  end
end
