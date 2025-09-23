defmodule Raxol.Terminal.Commands.OSCHandler.Selection do
  @moduledoc false

  alias Raxol.Terminal.{Emulator, Buffer.Selection}
  alias Raxol.Terminal.Commands.OSCHandler.SelectionParser
  require Raxol.Core.Runtime.Log

  @spec handle_51(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_51(emulator, data) do
    case SelectionParser.parse(data) do
      {:query, _} -> handle_selection_query(emulator)
      {:start, x, y} -> handle_selection_start(emulator, x, y)
      {:end, x, y} -> handle_selection_end(emulator, x, y)
      {:clear, _} -> handle_selection_clear(emulator)
      {:text, content} -> handle_selection_text(emulator, content)
      {:error, reason} -> handle_selection_error(emulator, reason, data)
    end
  end

  defp handle_selection_query(emulator) do
    text = Selection.get_text(emulator.screen_buffer)
    response = format_selection_response(text)
    {:ok, %{emulator | output_buffer: response}}
  end

  defp handle_selection_start(emulator, x, y) do
    new_buffer = Selection.start(emulator.screen_buffer, x, y)
    {:ok, %{emulator | screen_buffer: new_buffer}}
  end

  defp handle_selection_end(emulator, x, y) do
    new_buffer = Selection.update(emulator.screen_buffer, x, y)
    {:ok, %{emulator | screen_buffer: new_buffer}}
  end

  defp handle_selection_clear(emulator) do
    new_buffer = Selection.clear(emulator.screen_buffer)
    {:ok, %{emulator | screen_buffer: new_buffer}}
  end

  defp handle_selection_text(emulator, content) do
    case set_selection_text(emulator, content) do
      {:ok, new_emulator} ->
        {:ok, new_emulator}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning(
          "Failed to set selection text: #{inspect(reason)}"
        )

        {:error, reason, emulator}
    end
  end

  defp handle_selection_error(emulator, reason, data) do
    Raxol.Core.Runtime.Log.warning("Invalid OSC 51 command: #{inspect(data)}")
    {:error, reason, emulator}
  end

  defp format_selection_response(text) do
    # Format: OSC 51;text;content
    "\e]51;text;#{text}\e\\"
  end

  defp set_selection_text(emulator, content) do
    # Find the content in the buffer and set selection to cover it
    case find_text_in_buffer(emulator.screen_buffer, content) do
      {:ok, start_pos, end_pos} ->
        buffer1 =
          Selection.start(emulator.screen_buffer, start_pos.x, start_pos.y)

        buffer2 = Selection.update(buffer1, end_pos.x, end_pos.y)
        {:ok, %{emulator | screen_buffer: buffer2}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_text_in_buffer(buffer, content) do
    case Selection.get_buffer_text(buffer) do
      {:ok, text} ->
        case :binary.matches(text, content) do
          [] ->
            {:error, :text_not_found}
          [{start_idx, _} | _] ->
            # Convert byte index to screen coordinates
            start_pos = index_to_coordinates(buffer, start_idx)
            end_pos = index_to_coordinates(buffer, start_idx + byte_size(content))
            {:ok, start_pos, end_pos}
        end
      {:error, _reason} ->
        {:error, :text_not_found}
    end
  end

  defp index_to_coordinates(buffer, index) do
    width = buffer.width
    x = rem(index, width)
    y = div(index, width)
    %{x: x, y: y}
  end
end
