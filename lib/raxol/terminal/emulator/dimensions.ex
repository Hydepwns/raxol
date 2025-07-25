defmodule Raxol.Terminal.Emulator.Dimensions do
  @moduledoc """
  Dimension and resize operation functions extracted from the main emulator module.
  Handles terminal resizing and dimension getters.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer

  @type emulator :: Emulator.t()

  @doc """
  Gets the width of the terminal.
  """
  @spec get_width(emulator()) :: non_neg_integer()
  def get_width(emulator) do
    emulator.width
  end

  @doc """
  Gets the height of the terminal.
  """
  @spec get_height(emulator()) :: non_neg_integer()
  def get_height(emulator) do
    emulator.height
  end

  @doc """
  Resizes the terminal emulator to new dimensions.
  """
  @spec resize(emulator(), non_neg_integer(), non_neg_integer()) :: emulator()
  def resize(%Emulator{} = emulator, width, height)
      when width > 0 and height > 0 do
    # Resize main screen buffer
    main_buffer =
      if emulator.main_screen_buffer do
        ScreenBuffer.resize(emulator.main_screen_buffer, width, height)
      else
        ScreenBuffer.new(width, height)
      end

    # Resize alternate screen buffer
    alternate_buffer =
      if emulator.alternate_screen_buffer do
        ScreenBuffer.resize(emulator.alternate_screen_buffer, width, height)
      else
        ScreenBuffer.new(width, height)
      end

    # Update emulator with new dimensions and buffers
    %{
      emulator
      | width: width,
        height: height,
        main_screen_buffer: main_buffer,
        alternate_screen_buffer: alternate_buffer
    }
  end
end