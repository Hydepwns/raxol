defmodule Raxol.Core.Runtime.Rendering.Engine do
  @moduledoc """
  Provides the core rendering functionality for Raxol applications with functional error handling.

  This module is responsible for:
  * Rendering application views into screen buffers
  * Managing the rendering lifecycle
  * Coordinating with the output backends

  REFACTORED: All try/catch blocks replaced with functional error handling patterns.
  """

  require Raxol.Core.Runtime.Log
  use Raxol.Core.Behaviours.BaseManager


  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.UI.Layout.Engine, as: LayoutEngine
  alias Raxol.UI.Renderer, as: UIRenderer
  alias Raxol.UI.Theming.Theme

  defmodule State do
    @moduledoc false
    defstruct app_module: nil,
              dispatcher_pid: nil,
              width: 80,
              height: 24,
              # Screen buffer
              buffer: nil,
              # Default rendering target
              environment: :terminal,
              # For VSCode, etc.
              stdio_interface_pid: nil
  end

  # --- Public API ---

  @doc "Starts the Rendering Engine process."
  def start_link(initial_state_map) when is_map(initial_state_map) do
    Raxol.Core.Behaviours.BaseManager.start_link(__MODULE__, initial_state_map, name: __MODULE__)
  end

  # --- BaseManager Callbacks ---

  # Default BaseManager init implementation
  @impl true
  def init_manager(initial_state_map) do
    Raxol.Core.Runtime.Log.info("Rendering Engine initializing...")

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine init state map: #{inspect(initial_state_map)}"
    )

    state = struct!(State, initial_state_map)
    # Initialize buffer with initial dimensions
    initial_buffer = ScreenBuffer.new(state.width, state.height)
    new_state = %{state | buffer: initial_buffer}

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine init completed. State: #{inspect(new_state)}"
    )

    {:ok, new_state}
  end

  @impl true
  def handle_manager_cast(:render_frame, state) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine received :render_frame cast. State: #{inspect(state)}"
    )

    # Fetch the latest model AND theme context from the Dispatcher
    case GenServer.call(state.dispatcher_pid, :get_render_context) do
      {:ok, %{model: current_model, theme_id: current_theme_id}} ->
        Raxol.Core.Runtime.Log.debug(
          "Rendering Engine got render context: Model=#{inspect(current_model)}, Theme=#{inspect(current_theme_id)}"
        )

        # Fetch the actual theme struct using the ID
        theme =
          Theme.get(current_theme_id) || Theme.get(Theme.default_theme_id())

        case do_render_frame(current_model, theme, state) do
          {:ok, new_state} ->
            {:noreply, new_state}

          {:error, _reason, current_state} ->
            # Logged inside do_render_frame, just keep current state
            {:noreply, current_state}
        end

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "RenderingEngine failed to get render context from Dispatcher: #{inspect(reason)}"
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_manager_cast({:update_size, %{width: w, height: h}}, state) do
    Raxol.Core.Runtime.Log.debug(
      "RenderingEngine received size update: #{w}x#{h}"
    )

    new_state = %{state | width: w, height: h}

    resized_buffer = ScreenBuffer.new(w, h)
    {:noreply, %{new_state | buffer: resized_buffer}}
  end

  @impl true
  def handle_manager_call({:update_props, _new_props}, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_manager_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  # --- Private Helpers ---

  # Functional rendering pipeline replacing try/catch
  @spec do_render_frame(any(), any(), map()) :: any()
  defp do_render_frame(model, theme, state) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine executing do_render_frame. Model=#{inspect(model)}, Theme=#{inspect(theme)}, State=#{inspect(state)}"
    )

    with {:ok, view} <- safe_get_view(state.app_module, model),
         {:ok, positioned_elements} <- safe_apply_layout(view, state),
         {:ok, cells} <- safe_render_to_cells(positioned_elements, theme),
         {:ok, final_cells} <- safe_apply_plugin_transforms(cells, state),
         {:ok, new_state} <- safe_render_to_backend(final_cells, state) do
      {:ok, new_state}
    else
      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Render error",
          reason,
          nil,
          %{module: __MODULE__, state: state}
        )

        {:error, {:render_error, reason}, state}
    end
  end

  # Safe view retrieval using functional error handling
  @spec safe_get_view(module(), any()) :: any()
  defp safe_get_view(app_module, model) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Calling app_module.view(model)"
    )

    Raxol.Core.ErrorHandling.safe_call(fn ->
      case apply(app_module, :view, [model]) do
        view when not is_nil(view) ->
          Raxol.Core.Runtime.Log.debug(
            "Rendering Engine: Got view: #{inspect(view)}"
          )

          {:ok, view}

        _ ->
          {:error, :invalid_view}
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, {:view_error, reason}}
    end
  end

  # Safe layout application using functional error handling
  @spec safe_apply_layout(any(), map()) :: any()
  defp safe_apply_layout(view, state) do
    dimensions = %{width: state.width, height: state.height}

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Calculating layout with dimensions: #{inspect(dimensions)}"
    )

    Raxol.Core.ErrorHandling.safe_call(fn ->
      positioned_elements = LayoutEngine.apply_layout(view, dimensions)

      Raxol.Core.Runtime.Log.debug(
        "Rendering Engine: Got positioned elements: #{inspect(positioned_elements)}"
      )

      {:ok, positioned_elements}
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, {:layout_error, reason}}
    end
  end

  # Safe cell rendering using functional error handling
  @spec safe_render_to_cells(any(), any()) :: any()
  defp safe_render_to_cells(positioned_elements, theme) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Rendering to cells with theme: #{inspect(theme)}"
    )

    Raxol.Core.ErrorHandling.safe_call(fn ->
      cells = UIRenderer.render_to_cells(positioned_elements, theme)

      Raxol.Core.Runtime.Log.debug(
        "Rendering Engine: Got cells: #{inspect(cells)}"
      )

      {:ok, cells}
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, {:cell_rendering_error, reason}}
    end
  end

  # Safe plugin transforms using functional error handling
  @spec safe_apply_plugin_transforms(any(), map()) :: any()
  defp safe_apply_plugin_transforms(cells, state) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      processed_cells = apply_plugin_transforms(cells, state)
      {:ok, processed_cells}
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, {:plugin_transform_error, reason}}
    end
  end

  # Safe backend rendering
  @spec safe_render_to_backend(any(), map()) :: any()
  defp safe_render_to_backend(final_cells, state) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Sending final cells to backend: #{state.environment}"
    )

    case state.environment do
      :terminal ->
        render_to_terminal(final_cells, state)

      :vscode ->
        render_to_vscode(final_cells, state)

      other ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Unknown rendering environment",
          other,
          nil,
          %{module: __MODULE__, state: state}
        )

        {:error, :unknown_environment}
    end
  end

  # --- Private Rendering Backends ---

  @spec render_to_terminal(any(), map()) :: any()
  defp render_to_terminal(cells, state) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Executing render_to_terminal. State: #{inspect(state)}"
    )

    # Get current buffer or create if not exists
    screen_buffer =
      state.buffer || ScreenBuffer.new(state.width, state.height)

    # Transform cells into format {x, y, %Cell{...}}
    transformed_cells = transform_cells_for_update(cells)

    # Apply cells to the buffer
    updated_buffer =
      Enum.reduce(transformed_cells, screen_buffer, fn {x, y, cell}, buffer ->
        ScreenBuffer.write_char(buffer, x, y, cell.char || " ", %{
          foreground: cell.foreground,
          background: cell.background,
          bold: cell.bold,
          underline: cell.underline,
          italic: cell.italic
        })
      end)

    # Render the buffer using the Terminal Renderer
    output_string = Raxol.Terminal.Renderer.render(updated_buffer)

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Terminal output generated (length: #{String.length(output_string)})"
    )

    # Send rendered output (ANSI codes) to stdout
    # This assumes the process running this code has direct access to the terminal stdout.
    # In a more complex setup, this might involve sending to a dedicated IO process.
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Writing output string to IO"
    )

    IO.write(output_string)

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Finished writing output string to IO"
    )

    # Return updated state with the new buffer
    updated_state_with_buffer = Map.put(state, :buffer, updated_buffer)

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: render_to_terminal complete. New state: #{inspect(updated_state_with_buffer)}"
    )

    {:ok, updated_state_with_buffer}
  end

  @spec render_to_vscode(any(), map()) :: any()
  defp render_to_vscode(cells, state) do
    case state.stdio_interface_pid do
      nil -> {:error, :stdio_not_available}
      _ -> send_buffer_to_vscode(cells, state)
    end
  end

  @spec send_buffer_to_vscode(any(), map()) :: any()
  defp send_buffer_to_vscode(cells, _state) do
    # Convert cells to VS Code format
    _vscode_cells =
      Enum.map(cells, fn {x, y, char, fg, bg, _attrs} ->
        %{
          x: x,
          y: y,
          char: char,
          fg: convert_color_to_vscode(fg),
          bg: convert_color_to_vscode(bg),
          bold: false,
          underline: false,
          italic: false
        }
      end)

    # Note: Additional rendering modes can be added here as needed

    # Commented out as StdioInterface is likely obsolete
    # Raxol.StdioInterface.send_message(%{
    #   type: "render",
    #   payload: %{
    #     buffer: buffer,
    #     dimensions: dimensions
    #   }
    # })
    {:ok, :rendered}
  end

  # Terminal color code mapping
  @terminal_color_map %{
    0 => "black",
    1 => "red",
    2 => "green",
    3 => "yellow",
    4 => "blue",
    5 => "magenta",
    6 => "cyan",
    7 => "white",
    8 => "brightBlack",
    9 => "brightRed",
    10 => "brightGreen",
    11 => "brightYellow",
    12 => "brightBlue",
    13 => "brightMagenta",
    14 => "brightCyan",
    15 => "brightWhite"
  }

  @spec convert_color_to_vscode(Raxol.Terminal.Color.TrueColor.t()) :: any()
  defp convert_color_to_vscode(color) when is_integer(color) do
    @terminal_color_map[color] || "default"
  end

  @spec convert_color_to_vscode(any()) :: any()
  defp convert_color_to_vscode({r, g, b})
       when is_integer(r) and is_integer(g) and is_integer(b) do
    "rgb(#{r},#{g},#{b})"
  end

  @spec convert_color_to_vscode(Raxol.Terminal.Color.TrueColor.t()) :: any()
  defp convert_color_to_vscode(color) when is_binary(color), do: color
  @spec convert_color_to_vscode(any()) :: any()
  defp convert_color_to_vscode(_), do: "default"

  # Helper to transform cell format
  @spec transform_cells_for_update(any()) :: any()
  defp transform_cells_for_update(cells) when is_list(cells) do
    Enum.map(cells, fn {x, y, char, fg, bg, attrs_list} ->
      # Simpler version: Assume format is correct, remove case
      attrs_map = Enum.into(attrs_list || [], %{}, fn atom -> {atom, true} end)

      cell_attrs =
        %{
          foreground: fg,
          background: bg
        }
        |> Map.merge(Map.take(attrs_map, [:bold, :underline, :italic]))

      # Directly create cell using full name and correct key :style
      cell = %Raxol.Terminal.Cell{char: char, style: cell_attrs}
      {x, y, cell}
    end)
  end

  @spec apply_plugin_transforms(any(), map()) :: any()
  defp apply_plugin_transforms(cells, state) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Applying plugin transforms to #{length(cells)} cells"
    )

    # Get the plugin manager from the dispatcher
    case get_plugin_manager_from_dispatcher(state.dispatcher_pid) do
      {:ok, plugin_manager} ->
        # Create emulator state context for plugins
        emulator_state = %{
          width: state.width,
          height: state.height,
          environment: state.environment,
          buffer: state.buffer
        }

        # Process cells through plugins using CellProcessor
        {:ok, updated_manager, processed_cells, collected_commands} =
          Raxol.Plugins.CellProcessor.process(
            plugin_manager,
            cells,
            emulator_state
          )

        # Execute any collected commands (like escape sequences)
        execute_plugin_commands(collected_commands)

        # Update plugin manager state in dispatcher if needed
        _ =
          update_plugin_manager_in_dispatcher(
            state.dispatcher_pid,
            updated_manager
          )

        Raxol.Core.Runtime.Log.debug(
          "Rendering Engine: Plugin transforms applied. Processed cells: #{length(processed_cells)}, Commands: #{length(collected_commands)}"
        )

        processed_cells

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Rendering Engine: Could not get plugin manager for transforms",
          %{reason: reason, module: __MODULE__}
        )

        # Return original cells if plugin manager unavailable
        cells
    end
  end

  # Functional wrapper for dispatcher plugin manager retrieval
  @spec get_plugin_manager_from_dispatcher(String.t() | integer()) ::
          any() | nil
  defp get_plugin_manager_from_dispatcher(dispatcher_pid)
       when is_pid(dispatcher_pid) do
    with {:ok, response} <-
           safe_genserver_call(dispatcher_pid, :get_plugin_manager, 5000),
         {:ok, plugin_manager} <- validate_plugin_manager_response(response) do
      {:ok, plugin_manager}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec get_plugin_manager_from_dispatcher(any()) :: any() | nil
  defp get_plugin_manager_from_dispatcher(_), do: {:error, :invalid_dispatcher}

  # Safe GenServer call wrapper using functional error handling
  @spec safe_genserver_call(String.t() | integer(), String.t(), timeout()) ::
          any()
  defp safe_genserver_call(pid, message, timeout) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      GenServer.call(pid, message, timeout)
    end)
    |> case do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Rendering Engine: Error getting plugin manager from dispatcher",
          reason,
          nil,
          %{dispatcher_pid: pid}
        )

        {:error, :dispatcher_error}
    end
  end

  # Validate plugin manager response
  @spec validate_plugin_manager_response(any()) ::
          {:ok, any()} | {:error, any()}
  defp validate_plugin_manager_response({:ok, plugin_manager}) do
    {:ok, plugin_manager}
  end

  @spec validate_plugin_manager_response(any()) ::
          {:ok, any()} | {:error, any()}
  defp validate_plugin_manager_response({:error, reason}) do
    {:error, reason}
  end

  @spec validate_plugin_manager_response(any()) ::
          {:ok, any()} | {:error, any()}
  defp validate_plugin_manager_response(_) do
    {:error, :unexpected_response}
  end

  # Helper function to execute plugin commands (like escape sequences)
  @spec execute_plugin_commands(any()) :: any()
  defp execute_plugin_commands(commands)
       when is_list(commands) and length(commands) > 0 do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Executing #{length(commands)} plugin commands"
    )

    Enum.each(commands, fn command ->
      case is_binary(command) do
        true ->
          # Write escape sequences or other commands directly to output
          IO.write(command)

        false ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "Rendering Engine: Unknown plugin command format",
            %{command: command}
          )
      end
    end)
  end

  @spec execute_plugin_commands(any()) :: any()
  defp execute_plugin_commands(_), do: :ok

  # Functional wrapper for dispatcher plugin manager updates
  @spec update_plugin_manager_in_dispatcher(String.t() | integer(), any()) ::
          any()
  defp update_plugin_manager_in_dispatcher(dispatcher_pid, updated_manager)
       when is_pid(dispatcher_pid) do
    with :ok <-
           safe_genserver_cast(
             dispatcher_pid,
             {:update_plugin_manager, updated_manager}
           ) do
      :ok
    else
      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Rendering Engine: Error updating plugin manager in dispatcher",
          reason,
          nil,
          %{dispatcher_pid: dispatcher_pid}
        )

        {:error, reason}
    end
  end

  @spec update_plugin_manager_in_dispatcher(any(), any()) :: any()
  defp update_plugin_manager_in_dispatcher(_, _),
    do: {:error, :invalid_dispatcher}

  # Safe GenServer cast wrapper using functional error handling
  @spec safe_genserver_cast(String.t() | integer(), String.t()) :: any()
  defp safe_genserver_cast(pid, message) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      GenServer.cast(pid, message)
      :ok
    end)
  end
end
