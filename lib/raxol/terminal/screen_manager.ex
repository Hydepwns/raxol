defmodule Raxol.Terminal.ScreenManager do
  @moduledoc """
  Manages terminal screen state and updates.

  This module is responsible for:
  - Managing screen buffer state
  - Handling screen updates
  - Coordinating screen state transitions
  - Managing screen dimensions
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Updates the screen with a single update.

  ## Parameters
    * `emulator` - The current terminal emulator state
    * `update` - The screen update to apply

  ## Returns
    * `{updated_emulator, output}` - The updated emulator state and any output
  """
  @spec update_screen(Emulator.t(), map()) :: {Emulator.t(), any()}
  def update_screen(emulator, update) do
    buffer = Emulator.get_active_buffer(emulator)

    buffer =
      if Map.has_key?(update, :x) and Map.has_key?(update, :y) and
           Map.has_key?(update, :char) do
        ScreenBuffer.write_char(
          buffer,
          update.x,
          update.y,
          update.char,
          TextFormatting.new()
        )
      else
        buffer
      end

    new_emulator = Emulator.update_active_buffer(emulator, buffer)

    # Handle resize if present
    new_emulator =
      if Map.has_key?(update, :width) and Map.has_key?(update, :height) do
        handle_resize(new_emulator, update.width, update.height)
      else
        new_emulator
      end

    {new_emulator, nil}
  end

  @doc """
  Updates the screen with multiple updates.

  ## Parameters
    * `emulator` - The current terminal emulator state
    * `updates` - The list of screen updates to apply

  ## Returns
    * `{updated_emulator, output}` - The updated emulator state and any output
  """
  @spec batch_update_screen(Emulator.t(), [map()]) :: {Emulator.t(), any()}
  def batch_update_screen(emulator, updates) do
    buffer = Emulator.get_active_buffer(emulator)

    {buffer, new_emulator} =
      Enum.reduce(updates, {buffer, emulator}, fn update, {buf, emu} ->
        if Map.has_key?(update, :x) and Map.has_key?(update, :y) and
             Map.has_key?(update, :char) do
          new_buf =
            ScreenBuffer.write_char(
              buf,
              update.x,
              update.y,
              update.char,
              TextFormatting.new()
            )

          {new_buf, emu}
        else
          {buf, emu}
        end
      end)

    new_emulator = Emulator.update_active_buffer(new_emulator, buffer)

    # Handle resize if any update includes width/height
    new_emulator =
      Enum.reduce(updates, new_emulator, fn update, emu ->
        if Map.has_key?(update, :width) and Map.has_key?(update, :height) do
          handle_resize(emu, update.width, update.height)
        else
          emu
        end
      end)

    {new_emulator, nil}
  end

  @doc """
  Handles screen resize.

  ## Parameters
    * `emulator` - The current terminal emulator state
    * `width` - The new width
    * `height` - The new height

  ## Returns
    * `updated_emulator` - The updated emulator state
  """
  @spec handle_resize(Emulator.t(), integer(), integer()) :: Emulator.t()
  def handle_resize(emulator, width, height) do
    # Resize main buffer
    main_buffer =
      ScreenBuffer.resize(
        emulator.main_screen_buffer,
        width,
        height
      )

    emulator = %{emulator | main_screen_buffer: main_buffer}

    # Resize alternate buffer if it exists
    if emulator.alternate_screen_buffer do
      alt_buffer =
        ScreenBuffer.resize(
          emulator.alternate_screen_buffer,
          width,
          height
        )

      %{emulator | alternate_screen_buffer: alt_buffer}
    else
      emulator
    end
  end

  @doc """
  Gets the current screen dimensions.

  ## Parameters
    * `emulator` - The current terminal emulator state

  ## Returns
    * `{width, height}` - The current screen dimensions
  """
  @spec get_dimensions(Emulator.t()) :: {integer(), integer()}
  def get_dimensions(emulator) do
    buffer = Emulator.get_active_buffer(emulator)
    ScreenBuffer.get_dimensions(buffer)
  end

  @doc """
  Clears the screen.

  ## Parameters
    * `emulator` - The current terminal emulator state

  ## Returns
    * `updated_emulator` - The updated emulator state
  """
  @spec clear_screen(Emulator.t()) :: Emulator.t()
  def clear_screen(emulator) do
    buffer = Emulator.get_active_buffer(emulator)
    cleared_buffer = ScreenBuffer.clear(buffer, TextFormatting.new())
    Emulator.update_active_buffer(emulator, cleared_buffer)
  end
end
