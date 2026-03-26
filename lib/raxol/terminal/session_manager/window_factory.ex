defmodule Raxol.Terminal.SessionManager.WindowFactory do
  @moduledoc """
  Window and pane creation helpers for SessionManager.
  """

  alias Raxol.Terminal.SessionManager.{Pane, Window}

  @doc """
  Creates the initial set of windows for a new session.
  Returns {updated_session, windows}.
  """
  def create_initial_windows(session, config) do
    window_count = Map.get(config, :windows, 1)
    layout = Map.get(config, :layout, :main_horizontal)
    working_dir = Map.get(config, :working_directory, System.user_home!())

    windows =
      Enum.map(1..window_count, fn i ->
        window_id = generate_window_id()
        window_name = "window-#{i}"

        create_window_with_panes(window_id, session.id, window_name, %{
          layout: layout,
          working_directory: working_dir,
          panes: [%{command: nil}]
        })
      end)

    active_window = get_active_window(windows)
    {%{session | active_window: active_window}, windows}
  end

  @doc """
  Creates a window with the specified panes.
  """
  def create_window_with_panes(window_id, session_id, window_name, config) do
    now = System.monotonic_time(:millisecond)
    layout = Map.get(config, :layout, :main_horizontal)
    pane_configs = Map.get(config, :panes, [%{}])

    panes =
      pane_configs
      |> Enum.with_index()
      |> Enum.map(fn {pane_config, index} ->
        create_pane(window_id, pane_config, index)
      end)

    %Window{
      id: window_id,
      session_id: session_id,
      name: window_name,
      created_at: now,
      status: :active,
      layout: layout,
      panes: panes,
      active_pane: if(panes != [], do: List.first(panes).id, else: nil),
      metadata: Map.get(config, :metadata, %{})
    }
  end

  @doc """
  Creates a pane at a given index within a window.
  """
  def create_pane(window_id, config, index) do
    pane_id = generate_pane_id()
    working_dir = Map.get(config, :working_directory, System.user_home!())
    command = Map.get(config, :command)
    environment = Map.get(config, :environment, %{})

    {:ok, terminal_pid} =
      start_terminal_process(command, working_dir, environment)

    %Pane{
      id: pane_id,
      window_id: window_id,
      terminal: terminal_pid,
      position: {0, index * 25},
      size: {80, 24},
      command: command,
      working_directory: working_dir,
      environment: environment,
      status: :running,
      created_at: System.monotonic_time(:millisecond)
    }
  end

  @doc """
  Splits an existing pane in a direction, returning the new pane.
  """
  def split_pane(pane, direction, config) do
    new_pane_id = generate_pane_id()
    working_dir = Map.get(config, :working_directory, pane.working_directory)
    command = Map.get(config, :command)

    {:ok, terminal_pid} =
      start_terminal_process(command, working_dir, pane.environment)

    {new_position, new_size} = calculate_split_geometry(pane, direction)

    %Pane{
      id: new_pane_id,
      window_id: pane.window_id,
      terminal: terminal_pid,
      position: new_position,
      size: new_size,
      command: command,
      working_directory: working_dir,
      environment: pane.environment,
      status: :running,
      created_at: System.monotonic_time(:millisecond)
    }
  end

  defp calculate_split_geometry(pane, direction) do
    {x, y} = pane.position
    {width, height} = pane.size

    case direction do
      :horizontal ->
        new_height = div(height, 2)
        {{x, y + new_height}, {width, new_height}}

      :vertical ->
        new_width = div(width, 2)
        {{x + new_width, y}, {new_width, height}}
    end
  end

  defp start_terminal_process(command, working_dir, environment) do
    terminal_config = [
      command: command,
      working_directory: working_dir,
      environment: environment
    ]

    Raxol.Terminal.Emulator.start_link(terminal_config)
  end

  def generate_window_id do
    "window_" <> Base.encode16(:crypto.strong_rand_bytes(4))
  end

  def generate_pane_id do
    "pane_" <> Base.encode16(:crypto.strong_rand_bytes(4))
  end

  defp get_active_window([]), do: nil
  defp get_active_window([window | _]), do: window.id
end
