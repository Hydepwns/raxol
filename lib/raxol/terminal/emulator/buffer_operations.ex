defmodule Raxol.Terminal.Emulator.BufferOperations do
  @moduledoc """
  Buffer operation functions extracted from the main emulator module.
  Handles active buffer management and buffer switching operations.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer

  @type emulator :: Emulator.t()

  @doc """
  Gets the active buffer from the emulator based on active_buffer_type.
  """
  @spec get_active_buffer(emulator()) :: ScreenBuffer.t()
  def get_active_buffer(%Emulator{active_buffer_type: :main} = emulator) do
    emulator.main_screen_buffer
  end

  def get_active_buffer(%Emulator{active_buffer_type: :alternate} = emulator) do
    emulator.alternate_screen_buffer
  end

  @doc """
  Updates the active buffer with new buffer data.
  """
  @spec update_active_buffer(emulator(), ScreenBuffer.t()) :: emulator()
  def update_active_buffer(emulator, new_buffer) do
    case emulator.active_buffer_type do
      :main ->
        %{emulator | main_screen_buffer: new_buffer}

      :alternate ->
        %{emulator | alternate_screen_buffer: new_buffer}

      _ ->
        %{emulator | main_screen_buffer: new_buffer}
    end
  end

  @doc """
  Switches to the main screen buffer.
  """
  @spec switch_to_main_buffer(emulator()) :: emulator()
  def switch_to_main_buffer(emulator) do
    %{emulator | active_buffer_type: :main}
  end

  @doc """
  Switches to the alternate screen buffer.
  """
  @spec switch_to_alternate_buffer(emulator()) :: emulator()
  def switch_to_alternate_buffer(emulator) do
    %{emulator | active_buffer_type: :alternate}
  end

  @doc """
  Clears the entire screen and scrollback buffer.
  """
  @spec clear_entire_screen_and_scrollback(emulator()) :: emulator()
  def clear_entire_screen_and_scrollback(emulator) do
    emulator = Raxol.Terminal.Operations.ScreenOperations.clear_screen(emulator)
    %{emulator | scrollback_buffer: []}
  end

  @doc """
  Writes data to the output buffer.
  """
  @spec write_to_output(emulator(), binary()) :: emulator()
  def write_to_output(emulator, data) do
    Raxol.Terminal.OutputManager.write(emulator, data)
  end
end