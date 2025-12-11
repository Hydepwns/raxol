defmodule Raxol.Terminal.Emulator.BufferOperations do
  @moduledoc """
  Buffer operation functions extracted from the main emulator module.
  Handles active buffer management and buffer switching operations.
  """

  alias Raxol.Terminal.Emulator

  # Use map() to accept any emulator-like struct
  @type emulator :: map()

  @doc """
  Gets the active buffer from the emulator based on active_buffer_type.
  """
  @spec get_screen_buffer(map()) :: map()
  def get_screen_buffer(%Emulator{active_buffer_type: :main} = emulator) do
    emulator.main_screen_buffer
  end

  def get_screen_buffer(%Emulator{active_buffer_type: :alternate} = emulator) do
    emulator.alternate_screen_buffer
  end

  @doc """
  Updates the active buffer with new buffer data.
  """
  @spec update_active_buffer(emulator(), map()) :: emulator()
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
  def switch_to_main_buffer(emulator) do
    %{emulator | active_buffer_type: :main}
  end

  @doc """
  Switches to the alternate screen buffer.
  """
  def switch_to_alternate_buffer(emulator) do
    %{emulator | active_buffer_type: :alternate}
  end

  @doc """
  Clears the entire screen and scrollback buffer.
  """
  def clear_entire_screen_and_scrollback(emulator) do
    emulator = Raxol.Terminal.Operations.ScreenOperations.clear_screen(emulator)
    %{emulator | scrollback_buffer: []}
  end

  @doc """
  Writes data to the output buffer.
  """
  def write_to_output(emulator, data) do
    Raxol.Terminal.OutputManager.write(emulator, data)
  end

  @doc """
  Clears the scrollback buffer.
  """
  def clear_scrollback(emulator) do
    %{emulator | scrollback_buffer: []}
  end

  @doc """
  Switches to the alternate screen buffer.
  """
  def switch_to_alternate_screen(emulator) do
    switch_to_alternate_buffer(emulator)
  end

  @doc """
  Switches to the normal (main) screen buffer.
  """
  def switch_to_normal_screen(emulator) do
    switch_to_main_buffer(emulator)
  end
end
