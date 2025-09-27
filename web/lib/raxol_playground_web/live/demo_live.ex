defmodule RaxolPlaygroundWeb.DemoLive do
  use RaxolPlaygroundWeb, :live_view

  @impl true
  def mount(%{"demo" => demo_name}, _session, socket) do
    demo = get_demo(demo_name)

    socket =
      socket
      |> assign(:demo, demo)
      |> assign(:terminal_output, get_initial_output(demo))
      |> assign(:command_history, [])
      |> assign(:current_command, "")
      |> assign(:is_running, false)

    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    demos = list_demos()

    socket =
      socket
      |> assign(:demos, demos)
      |> assign(:selected_demo, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("run_command", %{"command" => command}, socket) do
    # Simulate command execution
    new_output = execute_demo_command(socket.assigns.demo, command)

    socket =
      socket
      |> assign(:terminal_output, socket.assigns.terminal_output <> new_output)
      |> assign(:command_history, [command | socket.assigns.command_history])
      |> assign(:current_command, "")

    {:noreply, socket}
  end

  def handle_event("update_command", %{"value" => command}, socket) do
    {:noreply, assign(socket, :current_command, command)}
  end

  def handle_event("select_demo", %{"demo" => demo_name}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/demos/#{demo_name}")}
  end

  def handle_event("clear_terminal", _params, socket) do
    initial_output = get_initial_output(socket.assigns.demo)
    {:noreply, assign(socket, :terminal_output, initial_output)}
  end

  @impl true
  def render(%{demo: nil} = assigns) do
    ~H"""
    <div class="demo-index min-h-screen bg-gray-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="text-center mb-12">
          <h1 class="text-4xl font-bold text-gray-900 mb-4">Interactive Demos</h1>
          <p class="text-xl text-gray-600">
            Experience Raxol components in realistic terminal scenarios
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          <%= for demo <- @demos do %>
            <div
              class="bg-white rounded-lg shadow-md hover:shadow-lg transition-shadow duration-200 cursor-pointer"
              phx-click="select_demo"
              phx-value-demo={demo.slug}
            >
              <!-- Terminal Preview -->
              <div class="bg-gray-900 rounded-t-lg p-4 h-48 overflow-hidden">
                <div class="bg-gray-800 rounded p-2 h-full">
                  <div class="flex items-center space-x-2 mb-2">
                    <div class="w-3 h-3 bg-red-500 rounded-full"></div>
                    <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
                    <div class="w-3 h-3 bg-green-500 rounded-full"></div>
                    <span class="text-gray-400 text-sm ml-2">Terminal</span>
                  </div>
                  <div class="text-green-400 font-mono text-xs">
                    <div class="text-gray-400">$ raxol demo <%= demo.slug %></div>
                    <div class="mt-1">
                      <%= raw(demo.preview) %>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Content -->
              <div class="p-6">
                <h3 class="text-xl font-semibold text-gray-900 mb-2"><%= demo.title %></h3>
                <p class="text-gray-600 mb-4"><%= demo.description %></p>

                <div class="flex items-center justify-between">
                  <div class="flex space-x-2">
                    <%= for tag <- demo.tags do %>
                      <span class="px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded">
                        <%= tag %>
                      </span>
                    <% end %>
                  </div>
                  <span class="text-sm text-gray-500"><%= demo.difficulty %></span>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="demo-container h-screen flex flex-col bg-gray-100">
      <!-- Header -->
      <div class="bg-white shadow-sm border-b px-6 py-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <button
              phx-click={JS.navigate(~p"/demos")}
              class="text-gray-600 hover:text-gray-900"
            >
              ← Back to Demos
            </button>
            <div>
              <h1 class="text-2xl font-bold text-gray-900"><%= @demo.title %></h1>
              <p class="text-gray-600"><%= @demo.description %></p>
            </div>
          </div>

          <div class="flex space-x-2">
            <button
              phx-click="clear_terminal"
              class="px-4 py-2 border border-gray-300 text-gray-700 rounded hover:bg-gray-50"
            >
              Clear
            </button>
            <button class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">
              Share Demo
            </button>
          </div>
        </div>
      </div>

      <!-- Terminal -->
      <div class="flex-1 p-6">
        <div class="h-full bg-gray-900 rounded-lg shadow-lg">
          <!-- Terminal Header -->
          <div class="bg-gray-800 rounded-t-lg px-4 py-3 flex items-center space-x-2">
            <div class="w-3 h-3 bg-red-500 rounded-full"></div>
            <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
            <div class="w-3 h-3 bg-green-500 rounded-full"></div>
            <span class="text-gray-400 text-sm ml-4">Raxol Demo - <%= @demo.title %></span>
          </div>

          <!-- Terminal Body -->
          <div class="flex flex-col h-full">
            <!-- Output Area -->
            <div class="flex-1 p-4 overflow-y-auto">
              <div class="text-green-400 font-mono text-sm whitespace-pre-wrap">
                <%= raw(@terminal_output) %>
              </div>
            </div>

            <!-- Input Area -->
            <div class="border-t border-gray-700 p-4">
              <form phx-submit="run_command" class="flex items-center space-x-2">
                <span class="text-green-400 font-mono">$</span>
                <input
                  type="text"
                  name="command"
                  value={@current_command}
                  phx-change="update_command"
                  placeholder="Type a command..."
                  class="flex-1 bg-transparent text-green-400 font-mono outline-none placeholder-gray-500"
                  autocomplete="off"
                />
              </form>
            </div>
          </div>
        </div>
      </div>

      <!-- Demo Info Sidebar -->
      <div class="fixed right-0 top-20 bottom-0 w-80 bg-white shadow-lg border-l transform translate-x-full transition-transform duration-300"
           id="demo-sidebar">
        <div class="p-6">
          <h3 class="text-lg font-semibold mb-4">Demo Information</h3>

          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Available Commands</label>
              <div class="space-y-1">
                <%= for command <- @demo.commands do %>
                  <div class="bg-gray-100 p-2 rounded text-sm font-mono">
                    <code><%= command.name %></code>
                    <p class="text-gray-600 text-xs mt-1"><%= command.description %></p>
                  </div>
                <% end %>
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Technologies</label>
              <div class="flex flex-wrap gap-1">
                <%= for tech <- @demo.technologies do %>
                  <span class="px-2 py-1 text-xs bg-green-100 text-green-800 rounded">
                    <%= tech %>
                  </span>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp list_demos do
    [
      %{
        slug: "file-browser",
        title: "File Browser",
        description: "Navigate files and directories with a TUI file manager",
        difficulty: "Intermediate",
        tags: ["navigation", "filesystem", "tree"],
        preview: "[DIR] Documents/\n[DIR] Downloads/\n[FILE] README.md\n[FILE] package.json",
        technologies: ["Raxol.UI", "File System"],
        commands: [
          %{name: "ls", description: "List directory contents"},
          %{name: "cd <dir>", description: "Change directory"},
          %{name: "mkdir <name>", description: "Create new directory"},
          %{name: "touch <name>", description: "Create new file"}
        ]
      },
      %{
        slug: "task-dashboard",
        title: "Task Dashboard",
        description: "Real-time task management with progress tracking",
        difficulty: "Advanced",
        tags: ["dashboard", "realtime", "progress"],
        preview: "+-- Active Tasks --------+\n| ########-- Deploy    |\n| ######---- Testing   |\n| ####------ Docs      |\n+------------------------+",
        technologies: ["Raxol.UI", "Phoenix PubSub", "Charts"],
        commands: [
          %{name: "task add <name>", description: "Add new task"},
          %{name: "task complete <id>", description: "Mark task as complete"},
          %{name: "task status", description: "Show all task statuses"},
          %{name: "dashboard refresh", description: "Refresh dashboard data"}
        ]
      },
      %{
        slug: "chat-interface",
        title: "Chat Interface",
        description: "Multi-user chat with emoji reactions and threading",
        difficulty: "Advanced",
        tags: ["chat", "realtime", "social"],
        preview: "Alice: Hello everyone!\nBob: Hey Alice, how's the demo?\nYou: Looking great!",
        technologies: ["Raxol.UI", "Phoenix Channels", "Presence"],
        commands: [
          %{name: "say <message>", description: "Send a message"},
          %{name: "react <symbol>", description: "React to last message"},
          %{name: "users", description: "List online users"},
          %{name: "history", description: "Show chat history"}
        ]
      },
      %{
        slug: "system-monitor",
        title: "System Monitor",
        description: "Live system metrics with graphs and alerts",
        difficulty: "Intermediate",
        tags: ["monitoring", "metrics", "graphs"],
        preview: "CPU: ████████░░ 80%\nRAM: ██████░░░░ 60%\nDisk: ███░░░░░░░ 30%\nNetwork: ↑1.2MB ↓850KB",
        technologies: ["Raxol.UI", "Telemetry", "Charts"],
        commands: [
          %{name: "top", description: "Show top processes"},
          %{name: "disk", description: "Show disk usage"},
          %{name: "network", description: "Show network stats"},
          %{name: "alerts", description: "View system alerts"}
        ]
      }
    ]
  end

  defp get_demo(slug) do
    Enum.find(list_demos(), &(&1.slug == slug))
  end

  defp get_initial_output(demo) do
    """
    Welcome to the #{demo.title} Demo!
    #{demo.description}

    Available commands: #{Enum.map_join(demo.commands, ", ", & &1.name)}
    Type 'help' for more information.

    >
    """
  end

  defp execute_demo_command(demo, command) do
    case {demo.slug, command} do
      {"file-browser", "ls"} ->
        """

        [DIR] Documents/       4.2 KB   Sep 26 2025 10.30
        [DIR] Downloads/       1.8 KB   Sep 26 2025 09.15
        [DIR] Pictures/        2.1 KB   Sep 25 2025 14.22
        [FILE] README.md       1.2 KB   Sep 26 2025 11.45
        [FILE] package.json      890 B   Sep 26 2025 10.20
        [FILE] index.html      3.4 KB   Sep 26 2025 12.00

        >
        """

      {"file-browser", "cd " <> dir} ->
        """

        Changed to directory: #{dir}
        >
        """

      {"task-dashboard", "task status"} ->
        """

        +-- Task Status ----------------------------+
        | ID | Task        | Progress | Status      |
        |----+-------------+----------+-------------|
        | 1  | Deploy      | ########-- 80%         |
        | 2  | Testing     | ######---- 60%         |
        | 3  | Docs        | ####------ 40%         |
        | 4  | Review      | ##-------- 20%         |
        +----+-------------+----------+-------------+

        >
        """

      {"chat-interface", "users"} ->
        """

        Online Users: 3
        * Alice     - Admin      - ONLINE Active
        * Bob       - Developer  - ONLINE Active
        * Charlie   - Designer   - AWAY   Away

        >
        """

      {"system-monitor", "top"} ->
        """

        +-- Top Processes ---------------------------+
        | PID   | NAME        | CPU  | MEMORY       |
        |-------+-------------+------+-------------|
        | 1234  | raxol       | 12%  | 156.2 MB    |
        | 5678  | phoenix     |  8%  | 89.4 MB     |
        | 9012  | postgres    |  3%  | 234.1 MB    |
        | 3456  | redis       |  1%  | 23.8 MB     |
        +-------+-------------+------+--------------+

        >
        """

      {_, "help"} ->
        """

        Available commands for #{demo.title}:
        #{Enum.map_join(demo.commands, "\n", fn cmd -> "  #{cmd.name} - #{cmd.description}" end)}

        >
        """

      {_, "clear"} ->
        get_initial_output(demo)

      _ ->
        """

        Command '#{command}' not recognized. Type 'help' for available commands.
        >
        """
    end
  end
end