defmodule Raxol.Terminal.Charset.Operations do
  @moduledoc """
  Provides operations for managing character sets and their state.
  """

  @doc """
  Designates a character set for a specific G-set.
  """
  def designate_charset(
        %Raxol.Terminal.Charset.Manager{} = state,
        g_set,
        charset
      )
      when g_set in [:g0, :g1, :g2, :g3] and
             charset in [
               :us_ascii,
               :dec_supplementary,
               :dec_special,
               :dec_technical
             ] do
    %{state | g_sets: Map.put(state.g_sets, g_set, charset)}
  end

  @doc """
  Invokes a G-set as the current character set.
  """
  def invoke_g_set(%Raxol.Terminal.Charset.Manager{} = state, g_set)
      when g_set in [:g0, :g1, :g2, :g3] do
    %{state | current_g_set: g_set}
  end

  @doc """
  Gets the current G-set.
  """
  def get_current_g_set(%Raxol.Terminal.Charset.Manager{} = state) do
    state.current_g_set
  end

  @doc """
  Gets the designated charset for a G-set.
  """
  def get_designated_charset(%Raxol.Terminal.Charset.Manager{} = state, g_set)
      when g_set in [:g0, :g1, :g2, :g3] do
    Map.get(state.g_sets, g_set)
  end

  @doc """
  Applies a single shift to the current character.
  """
  def apply_single_shift(%Raxol.Terminal.Charset.Manager{} = state, g_set)
      when g_set in [:g0, :g1, :g2, :g3] do
    %{state | single_shift: g_set}
  end

  @doc """
  Gets the current single shift.
  """
  def get_single_shift(%Raxol.Terminal.Charset.Manager{} = state) do
    state.single_shift
  end

  @doc """
  Handles setting the charset based on parameters and final byte.
  """
  def handle_set_charset(emulator, params_buffer, final_byte) do
    case get_charset_for_params(params_buffer, final_byte) do
      {:ok, charset} ->
        {:ok,
         %{emulator | charset_state: %{emulator.charset_state | g0: charset}}}

      :error ->
        {:ok, emulator}
    end
  end

  defp get_charset_for_params([], ?B), do: {:ok, :us_ascii}
  defp get_charset_for_params([], ?0), do: {:ok, :dec_special}
  defp get_charset_for_params([], ?>), do: {:ok, :dec_technical}
  defp get_charset_for_params([], ?<), do: {:ok, :dec_supplemental}
  defp get_charset_for_params([], "%5"), do: {:ok, :dec_supplemental_graphics}
  defp get_charset_for_params([], "%6"), do: {:ok, :dec_hebrew}
  defp get_charset_for_params([], "%7"), do: {:ok, :dec_greek}
  defp get_charset_for_params([], "%8"), do: {:ok, :dec_turkish}
  defp get_charset_for_params(_, _), do: :error
end
