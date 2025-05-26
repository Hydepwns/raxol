defmodule Raxol.Plugins.ClipboardPlugin do
  @moduledoc """
  Plugin for clipboard operations in Raxol.
  """

  @behaviour Raxol.Plugins.Plugin
  require Raxol.Core.Runtime.Log

  # Alias the new consolidated module
  alias Raxol.System.Clipboard

  @type t :: %__MODULE__{
          # Standard Plugin fields
          name: String.t(),
          version: String.t(),
          description: String.t(),
          enabled: boolean(),
          config: map(),
          dependencies: list(map()),
          api_version: String.t(),
          # Clipboard-specific state
          selection_active: boolean(),
          # {x, y}
          selection_start: {integer(), integer()} | nil,
          # {x, y}
          selection_end: {integer(), integer()} | nil,
          last_cells_at_selection: map() | nil
        }

  defstruct [
    # Standard fields
    name: "clipboard",
    version: "0.1.0",
    description: "Handles clipboard copy and paste.",
    enabled: true,
    config: %{},
    dependencies: [],
    api_version: "1.0.0",
    # Clipboard-specific state
    selection_active: false,
    selection_start: nil,
    selection_end: nil,
    last_cells_at_selection: nil
  ]

  @impl true
  def init(config \\ %{}) do
    # Initialize the plugin struct, merging provided config
    plugin_state = struct(__MODULE__, config)
    {:ok, plugin_state}
  end

  @impl true
  def handle_input(
        %__MODULE__{} = state,
        %{type: :key, modifiers: mods, key: ?c} = _event
      ) do
    if :ctrl in mods do
      Raxol.Core.Runtime.Log.debug("[Clipboard] Ctrl+C detected.")
      # Check for finalized selection and stored cells
      if is_tuple(state.selection_start) and is_tuple(state.selection_end) and
           is_map(state.last_cells_at_selection) do
        Raxol.Core.Runtime.Log.debug("[Clipboard] Triggering yank_selection.")
        result = yank_selection(state)
        new_state = clear_selection(state)
        # Store the yank result for debugging if needed
        new_state = Map.put(new_state, :last_yank_result, result)
        {:ok, new_state}
      else
        Raxol.Core.Runtime.Log.debug("[Clipboard] No complete selection available for copy.")
        {:ok, state}
      end
    else
      # Not Ctrl+C, just 'c' key or other modifiers
      {:ok, state}
    end
  end

  def handle_input(
        %__MODULE__{} = state,
        %{type: :key, modifiers: mods, key: ?v} = _event
      ) do
    if :ctrl in mods do
      Raxol.Core.Runtime.Log.debug("[Clipboard] Ctrl+V detected.")

      case get_clipboard_content() do
        {:ok, content} when content != "" ->
          Raxol.Core.Runtime.Log.debug("[Clipboard] Pasting content: #{content}")
          # Return command for Runtime to handle
          {:ok, state, {:command, {:paste, content}}}

        {:ok, ""} ->
          Raxol.Core.Runtime.Log.debug("[Clipboard] Clipboard is empty, nothing to paste.")
          {:ok, state}

        {:error, reason} ->
          Raxol.Core.Runtime.Log.error(
            "[Clipboard] Failed to get clipboard content: #{inspect(reason)}"
          )

          {:ok, state}
      end
    else
      # Not Ctrl+V, just 'v' key or other modifiers
      {:ok, state}
    end
  end

  # Catch-all for other map events or non-map events
  def handle_input(state, _event), do: {:ok, state}

  defp yank_selection(%__MODULE__{} = state) do
    case get_selected_text(state) do
      {:ok, text} ->
        # Call the new consolidated module
        case Clipboard.copy(text) do
          :ok ->
            Raxol.Core.Runtime.Log.debug("[Clipboard] Yanked selection to clipboard: #{text}")

          {:error, reason} ->
            Raxol.Core.Runtime.Log.error(
              "[Clipboard] Failed to yank selection: #{inspect(reason)}"
            )
        end

        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  defp get_selected_text(%__MODULE__{} = state) do
    case state do
      %{
        selection_start: start_pos,
        selection_end: end_pos,
        last_cells_at_selection: cells
      }
      when is_tuple(start_pos) and tuple_size(start_pos) == 2 and
             is_tuple(end_pos) and tuple_size(end_pos) == 2 and
             is_map(cells) ->
        # Determine top-left and bottom-right corners
        {sx, sy} = start_pos
        {ex, ey} = end_pos
        {min_x, max_x} = {min(sx, ex), max(sx, ex)}
        {min_y, max_y} = {min(sy, ey), max(sy, ey)}

        selected_lines =
          for y <- min_y..max_y do
            line_cells =
              for x <- min_x..max_x do
                cell = Map.get(cells, {x, y})

                cond do
                  is_nil(cell) -> nil
                  not is_integer(cell.char) -> nil
                  true -> <<cell.char::utf8>>
                end
              end

            # Filter out nils and join the characters for the line
            line_cells |> Enum.reject(&is_nil/1) |> Enum.join()
          end

        # Join all selected lines with newline
        {:ok, Enum.join(selected_lines, "\n")}

      _ ->
        # Catch-all if selection or cells are not ready
        {:error, :no_selection}
    end
  end

  defp clear_selection(state) do
    %{state | selection_active: false, selection_start: nil, selection_end: nil}
  end

  # Reads content from the system clipboard using the consolidated module.
  defp get_clipboard_content() do
    # Delegate directly to the new module
    Clipboard.paste()
  end

  @impl true
  def get_dependencies, do: []

  @impl true
  def get_api_version, do: "1.0.0"
end
