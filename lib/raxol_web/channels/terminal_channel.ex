defmodule RaxolWeb.TerminalChannel do
  @moduledoc """
  WebSocket channel for real-time terminal communication.

  This channel handles:
  - Terminal session initialization
  - Real-time input/output
  - Terminal resizing
  - Session management
  - Error handling
  - Rate limiting and security
  """

  use RaxolWeb, :channel
  alias Raxol.Terminal.Renderer
  alias Raxol.Terminal.Input
  require Raxol.Core.Runtime.Log
  require Logger
  import Raxol.Guards

  # Rate limiting configuration
  @rate_limit_per_second 100
  # 10KB max input size
  @max_input_size 1024 * 10

  @type t :: %__MODULE__{
          emulator: Emulator.t(),
          input: Input.t(),
          renderer: Renderer.t(),
          session_id: String.t(),
          user_id: String.t(),
          scrollback_limit: non_neg_integer()
        }

  defstruct [
    :emulator,
    :input,
    :renderer,
    :session_id,
    :user_id,
    :scrollback_limit
  ]

  # Get the configured modules at runtime
  defp emulator_module do
    Application.get_env(
      :raxol,
      :terminal_emulator_module,
      Raxol.Terminal.Emulator
    )
  end

  defp renderer_module do
    Application.get_env(
      :raxol,
      :terminal_renderer_module,
      Raxol.Terminal.Renderer
    )
  end

  @impl Phoenix.Channel
  @dialyzer {:nowarn_function, join: 3}
  def join("terminal:" <> session_id, _params, socket) do
    # Only allow if session_id is a valid UUID
    if valid_uuid?(session_id) do
      # Get scrollback limit from config or use default
      scrollback_limit =
        Application.get_env(:raxol, :terminal, %{})[:scrollback_lines] || 1000

      # Create new emulator instance
      emulator = emulator_module().new(80, 24, scrollback: scrollback_limit)
      input = Input.new()
      renderer = renderer_module().new(emulator.main_screen_buffer)

      state = %__MODULE__{
        emulator: emulator,
        input: input,
        renderer: renderer,
        session_id: session_id,
        user_id: socket.assigns.user_id,
        scrollback_limit: scrollback_limit
      }

      {:ok, assign(socket, :terminal_state, state)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl Phoenix.Channel
  def handle_in("input", %{"data" => data}, socket) do
    with :ok <- validate_input_size(data),
         :ok <- check_rate_limit(socket),
         :ok <- validate_input_data(data) do
      state = socket.assigns.terminal_state

      # Process input through emulator with error handling
      case process_input_safely(state.emulator, data) do
        {:ok, {emulator, _output}} ->
          renderer = %{
            state.renderer
            | screen_buffer: emulator.main_screen_buffer
          }

          new_state = %{state | emulator: emulator, renderer: renderer}
          socket = assign(socket, :terminal_state, new_state)

          # Get cursor position and visibility
          {cursor_x, cursor_y} = emulator_module().get_cursor_position(emulator)
          cursor_visible = emulator_module().get_cursor_visible(emulator)

          # Broadcast output to client
          broadcast!(socket, "output", %{
            html: renderer_module().render(renderer),
            cursor: %{x: cursor_x, y: cursor_y, visible: cursor_visible}
          })

          {:reply, :ok, socket}

        {:error, _reason} ->
          {:reply, {:error, %{reason: "input_processing_failed"}}, socket}
      end
    else
      {:error, :rate_limited} ->
        {:reply, {:error, %{reason: "rate_limited"}}, socket}

      {:error, :invalid_input} ->
        {:reply, {:error, %{reason: "invalid_input"}}, socket}
    end
  end

  # Rate limiting implementation
  defp check_rate_limit(socket) do
    user_id = socket.assigns.user_id
    key = "rate_limit:#{user_id}"

    # Ensure rate limit table exists (for testing scenarios)
    ensure_rate_limit_table()

    case :ets.lookup(:rate_limit_table, key) do
      [{^key, count, timestamp}] ->
        now = System.system_time(:second)

        if now - timestamp >= 1 do
          :ets.insert(:rate_limit_table, {key, 1, now})
          :ok
        else
          if count >= @rate_limit_per_second do
            {:error, :rate_limited}
          else
            :ets.insert(:rate_limit_table, {key, count + 1, timestamp})
            :ok
          end
        end

      [] ->
        :ets.insert(:rate_limit_table, {key, 1, System.system_time(:second)})
        :ok
    end
  end

  defp ensure_rate_limit_table do
    case :ets.info(:rate_limit_table) do
      :undefined ->
        :ets.new(:rate_limit_table, [:set, :public, :named_table])

      _ ->
        :ok
    end
  end

  defp validate_input_size(data)
       when is_binary(data) and byte_size(data) <= @max_input_size,
       do: :ok

  defp validate_input_size(_), do: {:error, :invalid_input}

  defp validate_input_data(data) when is_binary(data), do: :ok
  defp validate_input_data(_), do: {:error, :invalid_input}

  defp process_input_safely(emulator, data) do
    try do
      {:ok, emulator_module().process_input(emulator, data)}
    rescue
      _error ->
        {:error, :processing_failed}
    end
  end

  @impl Phoenix.Channel
  def handle_in("resize", %{"width" => width, "height" => height}, socket) do
    state = socket.assigns.terminal_state

    # Validate dimensions
    if is_integer(width) and is_integer(height) and width > 0 and height > 0 and
         width <= 200 and height <= 100 do
      # Resize emulator
      emulator = emulator_module().resize(state.emulator, width, height)
      renderer = %{state.renderer | screen_buffer: emulator.main_screen_buffer}

      new_state = %{state | emulator: emulator, renderer: renderer}
      socket = assign(socket, :terminal_state, new_state)

      # Get cursor position and visibility
      {cursor_x, cursor_y} = emulator_module().get_cursor_position(emulator)
      cursor_visible = emulator_module().get_cursor_visible(emulator)

      # Broadcast resize event to client
      broadcast!(socket, "resize", %{
        width: width,
        height: height,
        cursor: %{x: cursor_x, y: cursor_y, visible: cursor_visible}
      })

      {:reply, :ok, socket}
    else
      {:reply, {:error, %{reason: "invalid_dimensions"}}, socket}
    end
  end

  @impl Phoenix.Channel
  def handle_in("scroll", %{"offset" => offset}, socket) do
    state = socket.assigns.terminal_state
    emulator = state.emulator

    new_emulator =
      cond do
        offset < 0 ->
          Raxol.Terminal.Commands.Screen.scroll_up(emulator, abs(offset))

        offset > 0 ->
          Raxol.Terminal.Commands.Screen.scroll_down(emulator, abs(offset))

        true ->
          emulator
      end

    renderer = %{
      state.renderer
      | screen_buffer: new_emulator.main_screen_buffer
    }

    new_state = %{state | emulator: new_emulator, renderer: renderer}
    socket = assign(socket, :terminal_state, new_state)

    # Get cursor position and visibility
    {cursor_x, cursor_y} = emulator_module().get_cursor_position(new_emulator)
    cursor_visible = emulator_module().get_cursor_visible(new_emulator)

    # Optionally, include scrollback size for UI
    scrollback_size = length(new_emulator.scrollback_buffer || [])

    # Broadcast output to client (send html, not data)
    broadcast!(socket, "output", %{
      html: renderer_module().render(renderer),
      cursor: %{
        x: cursor_x,
        y: cursor_y,
        visible: cursor_visible
      },
      scrollback_size: scrollback_size
    })

    {:reply, :ok, socket}
  end

  @impl Phoenix.Channel
  def handle_in("theme", %{"theme" => theme}, socket) do
    state = socket.assigns.terminal_state

    # Validate theme
    if theme in ["dark", "light", "high-contrast"] do
      renderer = renderer_module().set_theme(state.renderer, theme)

      new_state = %{state | renderer: renderer}
      socket = assign(socket, :terminal_state, new_state)

      # Get cursor position and visibility
      {cursor_x, cursor_y} =
        emulator_module().get_cursor_position(state.emulator)

      cursor_visible = emulator_module().get_cursor_visible(state.emulator)

      push(socket, "output", %{
        html: renderer_module().render(renderer),
        cursor: %{
          x: cursor_x,
          y: cursor_y,
          visible: cursor_visible
        }
      })

      {:reply, :ok, socket}
    else
      {:reply, {:error, %{reason: "invalid_theme"}}, socket}
    end
  end

  @impl Phoenix.Channel
  def handle_in("set_scrollback_limit", %{"limit" => limit}, socket) do
    state = socket.assigns.terminal_state
    limit = if integer?(limit), do: limit, else: String.to_integer("#{limit}")

    # Validate limit
    if limit >= 100 and limit <= 10000 do
      emulator = %{state.emulator | scrollback_limit: limit}
      new_state = %{state | emulator: emulator}
      socket = assign(socket, :terminal_state, new_state)
      {:reply, :ok, socket}
    else
      {:reply, {:error, %{reason: "invalid_limit"}}, socket}
    end
  end

  @impl Phoenix.Channel
  def terminate(_reason, socket) do
    # Clean up rate limiting data
    if socket.assigns[:terminal_state] do
      user_id = socket.assigns.terminal_state.user_id
      # Only delete if table exists
      case :ets.info(:rate_limit_table) do
        :undefined -> :ok
        _ -> :ets.delete(:rate_limit_table, "rate_limit:#{user_id}")
      end
    end

    :ok
  end

  defp valid_uuid?(uuid) do
    case Ecto.UUID.cast(uuid) do
      {:ok, _} -> true
      :error -> false
    end
  end
end
