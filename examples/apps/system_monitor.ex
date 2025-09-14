defmodule SystemMonitor do
  @moduledoc """
  Real-time system monitoring dashboard built with Raxol.

  Provides comprehensive system metrics including CPU usage, memory consumption,
  disk I/O, network traffic, and process monitoring in an interactive terminal UI.

  ## Features

  * Real-time CPU, memory, disk, and network monitoring
  * Process list with sorting and filtering
  * Historical graphs and trending
  * Interactive controls and navigation
  * Customizable refresh rates and display options
  * System information and diagnostics

  ## Usage

      # Start with default settings
      SystemMonitor.start()
      
      # Start with custom refresh rate (in seconds)
      SystemMonitor.start(refresh_rate: 2)
      
      # Start in specific view mode
      SystemMonitor.start(view: :processes)

  ## Key Bindings

  * `q` - Quit application
  * `r` - Refresh data
  * `p` - Show processes view
  * `s` - Show system overview
  * `c` - Show CPU details
  * `m` - Show memory details  
  * `d` - Show disk details
  * `n` - Show network details
  * `g` - Toggle graphs
  * `h` - Show help
  * `+/-` - Adjust refresh rate
  """

  use Raxol.UI, framework: :universal
  require Logger

  # State structure
  defstruct [
    :current_view,
    :current_metrics,
    :refresh_rate,
    :show_graphs,
    :process_sort_by,
    :process_filter,
    :cpu_history,
    :memory_history,
    :network_history,
    :last_update,
    :help_visible
  ]

  # Default configuration
  @default_config %{
    refresh_rate: 1,
    show_graphs: true,
    max_history: 60,
    process_limit: 20
  }

  # Public API

  @doc """
  Start the system monitor.
  """
  def start(opts \\ []) do
    config = Map.merge(@default_config, Map.new(opts))

    initial_state = %__MODULE__{
      current_view: :overview,
      current_metrics: collect_initial_metrics(),
      refresh_rate: config.refresh_rate,
      show_graphs: config.show_graphs,
      process_sort_by: :memory,
      process_filter: "",
      cpu_history: :queue.new(),
      memory_history: :queue.new(),
      network_history: :queue.new(),
      last_update: System.system_time(:second),
      help_visible: false
    }

    case Raxol.UI.start_link(__MODULE__, initial_state) do
      {:ok, pid} ->
        Logger.info("System Monitor started")
        start_update_timer(pid, config.refresh_rate)
        run_monitor_loop(pid)

      {:error, reason} ->
        Logger.error("Failed to start monitor: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # UI Implementation

  @impl Raxol.UI
  def render(assigns) do
    ~H"""
    <div class="system-monitor">
      <%= render_header(assigns) %>
      <%= render_main_content(assigns) %>
      <%= render_footer(assigns) %>
      <%= if @help_visible, do: render_help_overlay(assigns) %>
    </div>
    """
  end

  defp render_header(assigns) do
    ~H"""
    <div class="monitor-header">
      <div class="title">
        🖥️  System Monitor - <%= @current_view |> to_string() |> String.capitalize() %>
      </div>
      <div class="stats">
        <span>Refresh: <%= @refresh_rate %>s</span>
        <span>|</span>
        <span>Last Update: <%= format_time(@last_update) %></span>
        <span>|</span>
        <span>Graphs: <%= if @show_graphs, do: "ON", else: "OFF" %></span>
      </div>
    </div>
    """
  end

  defp render_main_content(assigns) do
    case assigns.current_view do
      :overview -> render_overview(assigns)
      :cpu -> render_cpu_details(assigns)
      :memory -> render_memory_details(assigns)
      :disk -> render_disk_details(assigns)
      :network -> render_network_details(assigns)
      :processes -> render_processes(assigns)
      :system -> render_system_info(assigns)
      _ -> render_overview(assigns)
    end
  end

  defp render_footer(assigns) do
    ~H"""
    <div class="monitor-footer">
      <div class="navigation-help">
        [q]uit [h]elp [r]efresh [p]rocesses [s]ystem [c]pu [m]emory [d]isk [n]etwork [g]raphs +/- rate
      </div>
    </div>
    """
  end

  defp render_overview(assigns) do
    ~H"""
    <div class="overview-grid">
      <!-- CPU Panel -->
      <div class="panel cpu-panel">
        <div class="panel-title">CPU Usage</div>
        <div class="large-metric">
          <span class="metric-value"><%= @current_metrics.cpu.overall %>%</span>
          <div class="metric-bar">
            <div class="metric-fill cpu-fill" style={"width: #{@current_metrics.cpu.overall}%"}></div>
          </div>
        </div>
        <div class="metric-details">
          <div>Cores: <%= @current_metrics.cpu.count %></div>
          <div>Load Avg: <%= Float.round(@current_metrics.system.load_average, 2) %></div>
        </div>
      </div>

      <!-- Memory Panel -->
      <div class="panel memory-panel">
        <div class="panel-title">Memory Usage</div>
        <div class="large-metric">
          <span class="metric-value"><%= @current_metrics.memory.percentage %>%</span>
          <div class="metric-bar">
            <div class="metric-fill memory-fill" style={"width: #{@current_metrics.memory.percentage}%"}></div>
          </div>
        </div>
        <div class="metric-details">
          <div>Used: <%= format_bytes(@current_metrics.memory.processes) %></div>
          <div>Total: <%= format_bytes(@current_metrics.memory.total) %></div>
        </div>
      </div>

      <!-- Disk Panel -->
      <div class="panel disk-panel">
        <div class="panel-title">Disk Usage</div>
        <%= for disk <- Enum.take(@current_metrics.disk.disks, 3) do %>
          <div class="disk-entry">
            <span class="disk-name"><%= disk.mount %></span>
            <div class="metric-bar small">
              <div class="metric-fill disk-fill" style={"width: #{disk.percentage}%"}></div>
            </div>
            <span class="disk-percent"><%= disk.percentage %>%</span>
          </div>
        <% end %>
      </div>

      <!-- Network Panel -->
      <div class="panel network-panel">
        <div class="panel-title">Network</div>
        <%= case List.first(@current_metrics.network.interfaces) do %>
          <% nil -> %>
            <div class="no-data">No interfaces</div>
          <% interface -> %>
            <div class="network-stats">
              <div class="network-line">
                <span class="network-label">↓ RX:</span>
                <span class="network-value"><%= format_bytes(interface.rx_speed) %>/s</span>
              </div>
              <div class="network-line">
                <span class="network-label">↑ TX:</span>
                <span class="network-value"><%= format_bytes(interface.tx_speed) %>/s</span>
              </div>
            </div>
        <% end %>
      </div>

      <!-- Process Panel -->
      <div class="panel process-panel">
        <div class="panel-title">Top Processes</div>
        <%= for {proc, index} <- Enum.with_index(Enum.take(@current_metrics.processes, 5)) do %>
          <div class="process-entry">
            <span class="process-name"><%= String.slice(proc.name, 0..15) %></span>
            <span class="process-memory"><%= format_bytes(proc.memory) %></span>
          </div>
        <% end %>
      </div>

      <!-- System Panel -->
      <div class="panel system-panel">
        <div class="panel-title">System Info</div>
        <div class="system-stats">
          <div>OS: <%= @current_metrics.system.os %></div>
          <div>Uptime: <%= format_duration(@current_metrics.system.uptime) %></div>
          <div>Processes: <%= length(@current_metrics.processes) %></div>
        </div>
      </div>
    </div>
    """
  end

  defp render_cpu_details(assigns) do
    ~H"""
    <div class="cpu-details">
      <div class="panel">
        <div class="panel-title">CPU Details</div>
        <div class="cpu-overview">
          <div>Overall: <%= @current_metrics.cpu.overall %>%</div>
          <div>Cores: <%= @current_metrics.cpu.count %></div>
          <div>Load Average: <%= Float.round(@current_metrics.system.load_average, 2) %></div>
        </div>

        <%= if @show_graphs do %>
          <div class="chart cpu-history">
            <div class="chart-title">CPU History</div>
            <div class="chart-placeholder">[CPU History Chart - 60 data points]</div>
          </div>
        <% end %>

        <div class="cores-section">
          <h3>Per-Core Usage:</h3>
          <div class="cores-grid">
            <%= for {usage, core} <- @current_metrics.cpu.cores do %>
              <div class="core-item">
                <span class="core-label">Core <%= core %></span>
                <div class="core-bar">
                  <div class="core-fill" style={"width: #{usage}%"}></div>
                </div>
                <span class="core-percent"><%= usage %>%</span>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_memory_details(assigns) do
    ~H"""
    <div class="memory-details">
      <div class="panel">
        <div class="panel-title">Memory Details</div>
        <div class="memory-breakdown">
          <div class="memory-item">
            <span class="mem-label">Processes</span>
            <span class="mem-value"><%= format_bytes(@current_metrics.memory.processes) %></span>
            <div class="mem-bar">
              <div class="mem-fill" style={"width: #{(@current_metrics.memory.processes * 100 / @current_metrics.memory.total)}%"}></div>
            </div>
          </div>
          <div class="memory-item">
            <span class="mem-label">System</span>
            <span class="mem-value"><%= format_bytes(@current_metrics.memory.system) %></span>
            <div class="mem-bar">
              <div class="mem-fill" style={"width: #{(@current_metrics.memory.system * 100 / @current_metrics.memory.total)}%"}></div>
            </div>
          </div>
          <div class="memory-item">
            <span class="mem-label">Atom</span>
            <span class="mem-value"><%= format_bytes(@current_metrics.memory.atom) %></span>
            <div class="mem-bar">
              <div class="mem-fill" style={"width: #{(@current_metrics.memory.atom * 100 / @current_metrics.memory.total)}%"}></div>
            </div>
          </div>
        </div>

        <%= if @show_graphs do %>
          <div class="chart memory-history">
            <div class="chart-title">Memory History (%)</div>
            <div class="chart-placeholder">[Memory History Chart - 60 data points]</div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_disk_details(assigns) do
    ~H"""
    <div class="disk-details">
      <div class="panel">
        <div class="panel-title">Disk I/O</div>
        <div class="io-stats">
          <div>Read Speed: <%= format_bytes(@current_metrics.disk.read_speed) %>/s</div>
          <div>Write Speed: <%= format_bytes(@current_metrics.disk.write_speed) %>/s</div>
        </div>

        <h3>Mounted Filesystems:</h3>
        <div class="filesystem-list">
          <%= for disk <- @current_metrics.disk.disks do %>
            <div class="filesystem-item">
              <div class="fs-header">
                <span class="fs-mount"><%= disk.mount %></span>
                <span class="fs-percent"><%= disk.percentage %>%</span>
              </div>
              <div class="fs-details">
                <span>Used: <%= format_bytes(disk.used) %></span>
                <span>Total: <%= format_bytes(disk.total) %></span>
              </div>
              <div class="fs-bar">
                <div class="fs-fill" style={"width: #{disk.percentage}%"}></div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_network_details(assigns) do
    ~H"""
    <div class="network-details">
      <div class="panel">
        <div class="panel-title">Network Interfaces</div>
        
        <%= if @show_graphs do %>
          <div class="chart network-traffic">
            <div class="chart-title">Network Traffic (bytes/s)</div>
            <div class="chart-placeholder">[Network Traffic Chart - 60 data points]</div>
          </div>
        <% end %>

        <div class="interface-list">
          <%= for interface <- @current_metrics.network.interfaces do %>
            <div class="interface-item">
              <div class="if-header">
                <span class="if-name"><%= interface.name %></span>
                <span class="if-status">Active</span>
              </div>
              <div class="if-stats">
                <div class="if-stat">
                  <span class="if-label">↓ RX:</span>
                  <span class="if-value"><%= format_bytes(interface.rx_speed) %>/s</span>
                </div>
                <div class="if-stat">
                  <span class="if-label">↑ TX:</span>
                  <span class="if-value"><%= format_bytes(interface.tx_speed) %>/s</span>
                </div>
                <div class="if-stat">
                  <span class="if-label">Total:</span>
                  <span class="if-value"><%= format_bytes(interface.rx_bytes + interface.tx_bytes) %></span>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_processes(assigns) do
    filtered_processes =
      @current_metrics.processes
      |> Enum.sort_by(fn proc -> Map.get(proc, @process_sort_by, 0) end, :desc)
      |> Enum.filter(fn proc ->
        @process_filter == "" or
          String.contains?(
            String.downcase(proc.name),
            String.downcase(@process_filter)
          )
      end)
      |> Enum.take(20)

    ~H"""
    <div class="processes-view">
      <div class="panel">
        <div class="panel-title">Process List</div>
        <div class="process-controls">
          <span>Sort by: <%= @process_sort_by %></span>
          <span>Filter: <%= if @process_filter == "", do: "none", else: @process_filter %></span>
        </div>

        <div class="process-table">
          <div class="process-header">
            <span class="col-pid">PID</span>
            <span class="col-name">Name</span>
            <span class="col-memory">Memory</span>
            <span class="col-reductions">Reductions</span>
            <span class="col-status">Status</span>
          </div>
          <%= for proc <- filtered_processes do %>
            <div class="process-row">
              <span class="col-pid"><%= proc.pid %></span>
              <span class="col-name"><%= String.slice(proc.name, 0..20) %></span>
              <span class="col-memory"><%= format_bytes(proc.memory) %></span>
              <span class="col-reductions"><%= format_number(proc.reductions) %></span>
              <span class="col-status status-<%= proc.status %>"><%= proc.status %></span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_system_info(assigns) do
    ~H"""
    <div class="system-info">
      <div class="panel">
        <div class="panel-title">System Information</div>
        <div class="info-grid">
          <div class="info-section">
            <h3>Operating System</h3>
            <div class="info-item">
              <span class="info-label">OS:</span>
              <span class="info-value"><%= @current_metrics.system.os %></span>
            </div>
            <div class="info-item">
              <span class="info-label">Uptime:</span>
              <span class="info-value"><%= format_duration(@current_metrics.system.uptime) %></span>
            </div>
            <div class="info-item">
              <span class="info-label">Load Avg:</span>
              <span class="info-value"><%= Float.round(@current_metrics.system.load_average, 2) %></span>
            </div>
          </div>

          <div class="info-section">
            <h3>Runtime</h3>
            <div class="info-item">
              <span class="info-label">Erlang:</span>
              <span class="info-value"><%= @current_metrics.system.erlang_version %></span>
            </div>
            <div class="info-item">
              <span class="info-label">Elixir:</span>
              <span class="info-value"><%= @current_metrics.system.elixir_version %></span>
            </div>
            <div class="info-item">
              <span class="info-label">Processors:</span>
              <span class="info-value"><%= @current_metrics.system.processors %></span>
            </div>
            <div class="info-item">
              <span class="info-label">Schedulers:</span>
              <span class="info-value"><%= @current_metrics.system.schedulers %></span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_help_overlay(assigns) do
    ~H"""
    <div class="help-overlay">
      <div class="help-content">
        <h2>System Monitor Help</h2>
        
        <div class="help-section">
          <h3>Navigation</h3>
          <ul>
            <li><code>s</code> - System overview</li>
            <li><code>c</code> - CPU details</li>
            <li><code>m</code> - Memory details</li>
            <li><code>d</code> - Disk details</li>
            <li><code>n</code> - Network details</li>
            <li><code>p</code> - Process list</li>
          </ul>
        </div>
        
        <div class="help-section">
          <h3>Controls</h3>
          <ul>
            <li><code>r</code> - Refresh data</li>
            <li><code>g</code> - Toggle graphs</li>
            <li><code>+/-</code> - Adjust refresh rate</li>
            <li><code>q</code> - Quit</li>
            <li><code>h</code> - Toggle help</li>
          </ul>
        </div>
        
        <div class="help-footer">
          Press any key to close help
        </div>
      </div>
    </div>
    """
  end

  # Helper Functions

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes < 1024 -> "#{bytes}B"
      bytes < 1_048_576 -> "#{div(bytes, 1024)}KB"
      bytes < 1_073_741_824 -> "#{div(bytes, 1_048_576)}MB"
      true -> "#{Float.round(bytes / 1_073_741_824, 1)}GB"
    end
  end

  defp format_bytes(_), do: "0B"

  defp format_number(num) when is_integer(num) do
    num |> Integer.to_string() |> add_commas()
  end

  defp format_number(_), do: "0"

  defp add_commas(str) do
    str
    |> String.reverse()
    |> String.replace(~r/(\d{3})/, "\\1,")
    |> String.reverse()
    |> String.trim_leading(",")
  end

  defp format_duration(seconds) when is_integer(seconds) do
    days = div(seconds, 86400)
    hours = div(rem(seconds, 86400), 3600)
    mins = div(rem(seconds, 3600), 60)

    cond do
      days > 0 -> "#{days}d #{hours}h"
      hours > 0 -> "#{hours}h #{mins}m"
      true -> "#{mins}m"
    end
  end

  defp format_duration(_), do: "0m"

  defp format_time(timestamp) do
    timestamp
    |> DateTime.from_unix!()
    |> Calendar.strftime("%H:%M:%S")
  end

  # Mock data functions

  defp collect_initial_metrics do
    %{
      cpu: %{
        overall: 45,
        count: 8,
        cores: Enum.map(0..7, fn i -> {15 + :rand.uniform(70), i} end)
      },
      memory: %{
        total: 16_000_000_000,
        processes: 8_000_000_000,
        system: 2_000_000_000,
        atom: 50_000_000,
        binary: 100_000_000,
        ets: 25_000_000,
        percentage: 62
      },
      disk: %{
        read_speed: 1_500_000,
        write_speed: 800_000,
        disks: [
          %{
            mount: "/",
            used: 120_000_000_000,
            total: 250_000_000_000,
            percentage: 48
          },
          %{
            mount: "/home",
            used: 80_000_000_000,
            total: 500_000_000_000,
            percentage: 16
          }
        ]
      },
      network: %{
        interfaces: [
          %{
            name: "eth0",
            rx_speed: 2_500_000,
            tx_speed: 1_200_000,
            rx_bytes: 1_500_000_000,
            tx_bytes: 800_000_000
          }
        ]
      },
      processes: generate_mock_processes(),
      system: %{
        os: "Linux 5.15.0",
        erlang_version: "26.0",
        elixir_version: "1.15.0",
        processors: 8,
        schedulers: 8,
        uptime: 1_234_567,
        load_average: 1.45
      }
    }
  end

  defp generate_mock_processes do
    process_names = [
      "beam.smp",
      "systemd",
      "kthreadd",
      "rcu_gp",
      "nginx",
      "postgres",
      "redis-server",
      "chrome",
      "firefox",
      "code",
      "iex",
      "mix"
    ]

    Enum.map(1..50, fn i ->
      name = Enum.random(process_names)

      %{
        pid: 1000 + i,
        name: "#{name}-#{i}",
        memory: :rand.uniform(100_000_000),
        reductions: :rand.uniform(1_000_000),
        status: Enum.random([:running, :waiting, :suspended]),
        function: "gen_server:loop/#{:rand.uniform(3)}"
      }
    end)
  end

  # Process loop functions

  defp start_update_timer(_pid, refresh_rate) do
    # In a real implementation, this would start a timer
    :ok
  end

  defp run_monitor_loop(pid) do
    receive do
      {:stop} ->
        Raxol.UI.stop(pid)

      {:refresh} ->
        Raxol.UI.refresh(pid)
        run_monitor_loop(pid)

      other ->
        Logger.debug("Monitor loop received: #{inspect(other)}")
        run_monitor_loop(pid)
    end
  end
end
