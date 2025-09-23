defmodule Raxol.Terminal.ScreenBuffer.Charset do
  @moduledoc """
  Handles character set operations for the screen buffer.
  """

  def init do
    %{
      g0: :us_ascii,
      g1: :us_ascii,
      g2: :us_ascii,
      g3: :us_ascii,
      gl: :g0,
      gr: :g2,
      single_shift: nil
    }
  end

  def designate(state, slot, charset) do
    Map.put(state, slot, charset)
  end

  def invoke_g_set(state, slot) do
    Map.put(state, :gl, slot)
  end

  def get_current_g_set(state) do
    state.gl
  end

  def get_designated(state, slot) do
    Map.get(state, slot)
  end

  @spec reset(map()) :: map()
  def reset(_state) do
    init()
  end

  def apply_single_shift(state, slot) do
    Map.put(state, :single_shift, slot)
  end

  def get_single_shift(state) do
    state.single_shift
  end
end
