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
  alias Raxol.Terminal.Emulator
  require Raxol.Core.Runtime.Log
  require Logger

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
    handle_terminal_join(valid_uuid?(session_id), session_id, socket)
  end

  defp handle_terminal_join(false, _session_id, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  defp handle_terminal_join(true, session_id, socket) do
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
  end

  @impl Phoenix.Channel
  def handle_in("input", %{"data" => data}, socket) do
    case validate_and_process_input(data, socket) do
      {:ok, new_state, cursor_info} ->
        socket = assign(socket, :terminal_state, new_state)

        broadcast!(
          socket,
          "output",
          Map.merge(
            %{html: renderer_module().render(new_state.renderer)},
            cursor_info
          )
        )

        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  @impl Phoenix.Channel
  def handle_in("resize", %{"width" => width, "height" => height}, socket) do
    case validate_dimensions(width, height) do
      :ok ->
        state = socket.assigns.terminal_state
        {new_state, cursor_info} = resize_terminal(state, width, height)
        socket = assign(socket, :terminal_state, new_state)

        broadcast!(
          socket,
          "resize",
          Map.merge(%{width: width, height: height}, cursor_info)
        )

        {:reply, :ok, socket}

      :error ->
        {:reply, {:error, %{reason: "invalid_dimensions"}}, socket}
    end
  end

  @impl Phoenix.Channel
  def handle_in("scroll", %{"offset" => offset}, socket) do
    state = socket.assigns.terminal_state
    emulator = state.emulator

    new_emulator = apply_scroll_offset(emulator, offset)

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
    handle_theme_change(theme in ["dark", "light", "high-contrast"], theme, state, socket)
  end

  @impl Phoenix.Channel
  def handle_in("set_scrollback_limit", %{"limit" => limit}, socket) do
    state = socket.assigns.terminal_state
    limit = case is_integer(limit) do
      true -> limit
      false -> String.to_integer("#{limit}")
    end
    handle_scrollback_limit_change(limit >= 100 and limit <= 10_000, limit, state, socket)
  end

  defp handle_theme_change(false, _theme, _state, socket) do
    {:reply, {:error, %{reason: "invalid_theme"}}, socket}
  end

  defp handle_theme_change(true, theme, state, socket) do
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
  end


  defp handle_scrollback_limit_change(false, _limit, _state, socket) do
    {:reply, {:error, %{reason: "invalid_limit"}}, socket}
  end

  defp handle_scrollback_limit_change(true, limit, state, socket) do
    emulator = %{state.emulator | scrollback_limit: limit}
    new_state = %{state | emulator: emulator}
    socket = assign(socket, :terminal_state, new_state)
    {:reply, :ok, socket}
  end

  defp validate_and_process_input(data, socket) do
    with :ok <- validate_input_size(data),
         :ok <- check_rate_limit(socket),
         :ok <- validate_input_data(data) do
      state = socket.assigns.terminal_state

      case process_input_safely(state.emulator, data) do
        {:ok, {emulator, _output}} ->
          renderer = %{
            state.renderer
            | screen_buffer: emulator.main_screen_buffer
          }

          new_state = %{state | emulator: emulator, renderer: renderer}

          {cursor_x, cursor_y} = emulator_module().get_cursor_position(emulator)
          cursor_visible = emulator_module().get_cursor_visible(emulator)

          cursor_info = %{
            cursor: %{x: cursor_x, y: cursor_y, visible: cursor_visible}
          }

          {:ok, new_state, cursor_info}

        {:error, _reason} ->
          {:error, "input_processing_failed"}
      end
    else
      {:error, :rate_limited} -> {:error, "rate_limited"}
      {:error, :invalid_input} -> {:error, "invalid_input"}
    end
  end

  # Rate limiting implementation
  defp check_rate_limit(socket) do
    user_id = socket.assigns.user_id
    key = "rate_limit:#{user_id}"

    # Ensure rate limit table exists (for testing scenarios)
    ensure_rate_limit_table()

    case Raxol.Core.CompilerState.safe_lookup(:rate_limit_table, key) do
      {:ok, [{^key, count, timestamp}]} ->
        check_existing_rate_limit(key, count, timestamp)

      {:ok, []} ->
        Raxol.Core.CompilerState.safe_insert(
          :rate_limit_table,
          {key, 1, System.system_time(:second)}
        )

        :ok

      {:error, :table_not_found} ->
        # Table doesn't exist, ensure it exists and try again
        ensure_rate_limit_table()

        Raxol.Core.CompilerState.safe_insert(
          :rate_limit_table,
          {key, 1, System.system_time(:second)}
        )

        :ok
    end
  end

  defp check_existing_rate_limit(key, count, timestamp) do
    now = System.system_time(:second)
    check_rate_limit_status(key, count, timestamp, now)
  end

  defp check_rate_limit_status(key, _count, timestamp, now)
       when now - timestamp >= 1 do
    :ets.insert(:rate_limit_table, {key, 1, now})
    :ok
  end

  defp check_rate_limit_status(_key, count, _timestamp, _now)
       when count >= @rate_limit_per_second do
    {:error, :rate_limited}
  end

  defp check_rate_limit_status(key, count, timestamp, _now) do
    :ets.insert(:rate_limit_table, {key, count + 1, timestamp})
    :ok
  end

  defp ensure_rate_limit_table do
    Raxol.Core.CompilerState.ensure_table(:rate_limit_table, [
      :set,
      :public,
      :named_table
    ])
  end

  defp validate_input_size(data)
       when is_binary(data) and byte_size(data) <= @max_input_size,
       do: :ok

  defp validate_input_size(_), do: {:error, :invalid_input}

  defp validate_input_data(data) when is_binary(data), do: :ok
  defp validate_input_data(_), do: {:error, :invalid_input}

  defp process_input_safely(emulator, data) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           emulator_module().process_input(emulator, data)
         end) do
      {:ok, result} -> {:ok, result}
      {:error, _reason} -> {:error, :processing_failed}
    end
  end

  defp validate_dimensions(width, height) do
    dimensions_valid = is_integer(width) and is_integer(height) and width > 0 and height > 0 and width <= 200 and height <= 100
    validate_dimensions_result(dimensions_valid)
  end

  defp validate_dimensions_result(true), do: :ok
  defp validate_dimensions_result(false), do: :error

  defp apply_scroll_offset(emulator, offset) when offset < 0 do
    Raxol.Terminal.Commands.Screen.scroll_up(emulator, abs(offset))
  end

  defp apply_scroll_offset(emulator, offset) when offset > 0 do
    Raxol.Terminal.Commands.Screen.scroll_down(emulator, abs(offset))
  end

  defp apply_scroll_offset(emulator, _offset), do: emulator

  defp resize_terminal(state, width, height) do
    emulator = emulator_module().resize(state.emulator, width, height)
    renderer = %{state.renderer | screen_buffer: emulator.main_screen_buffer}
    new_state = %{state | emulator: emulator, renderer: renderer}

    {cursor_x, cursor_y} = emulator_module().get_cursor_position(emulator)
    cursor_visible = emulator_module().get_cursor_visible(emulator)

    cursor_info = %{
      cursor: %{x: cursor_x, y: cursor_y, visible: cursor_visible}
    }

    {new_state, cursor_info}
  end

  @impl Phoenix.Channel
  def terminate(_reason, socket) do
    # Clean up rate limiting data
    cleanup_rate_limiting_data(socket.assigns[:terminal_state], socket)
    :ok
  end

  defp cleanup_rate_limiting_data(nil, _socket) do
    :ok
  end

  defp cleanup_rate_limiting_data(terminal_state, _socket) do
    user_id = terminal_state.user_id
    # Only delete if table exists
    case :ets.info(:rate_limit_table) do
      :undefined -> :ok
      _ -> :ets.delete(:rate_limit_table, "rate_limit:#{user_id}")
    end
  end

  defp valid_uuid?(uuid) do
    case Ecto.UUID.cast(uuid) do
      {:ok, _} -> true
      :error -> false
    end
  end
end
