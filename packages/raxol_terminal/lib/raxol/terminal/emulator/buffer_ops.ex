defmodule Raxol.Terminal.Emulator.BufferOps do
  @moduledoc false

  alias Raxol.Core.Runtime.Log
  alias Raxol.Terminal.Emulator.BufferOperations

  def get_screen_buffer(%{
        active_buffer_type: :alternate,
        alternate_screen_buffer: buffer
      })
      when buffer != nil,
      do: buffer

  def get_screen_buffer(%{main_screen_buffer: buffer}), do: buffer
  def get_screen_buffer(_), do: nil

  def update_active_buffer(emulator, buffer),
    do: BufferOperations.update_active_buffer(emulator, buffer)

  def switch_to_alternate_screen(emulator),
    do: BufferOperations.switch_to_alternate_screen(emulator)

  def switch_to_normal_screen(emulator),
    do: BufferOperations.switch_to_normal_screen(emulator)

  def clear_scrollback(emulator),
    do: BufferOperations.clear_scrollback(emulator)

  def write_to_output(emulator, data) do
    BufferOperations.write_to_output(emulator, data)
  rescue
    error ->
      Log.warning("write_to_output failed: #{inspect(error)}")
      emulator
  end
end
