defmodule RaxolPlaygroundWeb.ReplLive do
  use RaxolPlaygroundWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:history, [])
      |> assign(:current_input, "")
      |> assign(:cursor_position, 0)
      |> assign(:command_history, [])
      |> assign(:history_index, 0)
      |> assign(:session_id, generate_session_id())

    {:ok, socket}
  end

  @impl true
  def handle_event("execute_code", %{"code" => code}, socket) do
    result = evaluate_elixir_code(code)

    history_entry = %{
      input: code,
      output: result.output,
      timestamp: DateTime.utc_now(),
      status: result.status,
      execution_time: result.execution_time
    }

    updated_history = [history_entry | socket.assigns.history]
    updated_command_history = [code | socket.assigns.command_history]

    socket =
      socket
      |> assign(:history, updated_history)
      |> assign(:command_history, updated_command_history)
      |> assign(:current_input, "")
      |> assign(:history_index, 0)

    {:noreply, socket}
  end

  def handle_event("update_input", %{"input" => input}, socket) do
    {:noreply, assign(socket, :current_input, input)}
  end

  def handle_event("navigate_history", %{"direction" => direction}, socket) do
    command_history = socket.assigns.command_history
    current_index = socket.assigns.history_index

    {new_index, new_input} = case direction do
      "up" when current_index < length(command_history) ->
        index = current_index + 1
        input = Enum.at(command_history, index - 1, "")
        {index, input}

      "down" when current_index > 0 ->
        index = current_index - 1
        input = if index == 0, do: "", else: Enum.at(command_history, index - 1, "")
        {index, input}

      _ ->
        {current_index, socket.assigns.current_input}
    end

    socket =
      socket
      |> assign(:history_index, new_index)
      |> assign(:current_input, new_input)

    {:noreply, socket}
  end

  def handle_event("clear_repl", _params, socket) do
    socket =
      socket
      |> assign(:history, [])
      |> assign(:current_input, "")
      |> assign(:history_index, 0)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="repl-container h-screen flex flex-col bg-gray-900 text-green-400">
      <!-- Header -->
      <div class="repl-header p-4 bg-gray-800 border-b border-gray-700">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-xl font-bold text-white">Raxol Interactive REPL</h1>
            <p class="text-sm text-gray-400 mt-1">
              Interactive Elixir environment with Raxol components
            </p>
          </div>

          <div class="flex gap-2">
            <button
              phx-click="clear_repl"
              class="px-3 py-1 bg-red-600 text-white text-sm rounded hover:bg-red-700"
            >
              Clear
            </button>

            <div class="text-sm text-gray-400 px-3 py-1">
              Session: <%= String.slice(@session_id, 0..7) %>
            </div>
          </div>
        </div>
      </div>

      <!-- REPL History -->
      <div class="repl-history flex-1 overflow-y-auto p-4 font-mono text-sm">
        <!-- Welcome Message -->
        <%= if Enum.empty?(@history) do %>
          <div class="welcome-message mb-6 text-gray-400">
            <div class="mb-2">Welcome to Raxol Interactive REPL!</div>
            <div class="mb-2">Try some examples:</div>
            <div class="ml-4 space-y-1">
              <div>• <span class="text-green-400">IO.puts("Hello Raxol!")</span></div>
              <div>• <span class="text-green-400">Enum.map([1, 2, 3], &(&1 * 2))</span></div>
              <div>• <span class="text-green-400">use Raxol.UI, framework: :react</span></div>
              <div>• <span class="text-green-400">:observer.start()</span> # Start Observer</div>
            </div>
            <div class="mt-4 text-xs">Use ↑/↓ arrows to navigate command history</div>
          </div>
        <% end %>

        <!-- History Entries -->
        <%= for {entry, index} <- Enum.with_index(Enum.reverse(@history)) do %>
          <div class="repl-entry mb-4">
            <!-- Input -->
            <div class="repl-input flex items-start">
              <div class="prompt text-yellow-400 mr-2 flex-shrink-0">
                iex(<%= length(@history) - index %>)>
              </div>
              <div class="input-text text-white flex-1 whitespace-pre-wrap"><%= entry.input %></div>
            </div>

            <!-- Output -->
            <div class="repl-output mt-1 ml-12">
              <div class={output_class(entry.status)}>
                <pre class="whitespace-pre-wrap"><%= entry.output %></pre>
              </div>

              <!-- Metadata -->
              <div class="metadata text-xs text-gray-500 mt-1 flex items-center gap-4">
                <span>
                  <%= format_timestamp(entry.timestamp) %>
                </span>
                <span>
                  <%= entry.execution_time %>μs
                </span>
                <span class={status_class(entry.status)}>
                  <%= String.upcase(to_string(entry.status)) %>
                </span>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Input Area -->
      <div class="repl-input-area bg-gray-800 border-t border-gray-700 p-4">
        <div class="flex items-start">
          <div class="prompt text-yellow-400 mr-2 flex-shrink-0 font-mono">
            iex(<%= length(@history) + 1 %>)>
          </div>

          <div class="input-container flex-1">
            <textarea
              phx-hook="ReplInput"
              id="repl-input"
              rows="1"
              placeholder="Enter Elixir code here..."
              value={@current_input}
              phx-keyup="update_input"
              phx-key="Enter"
              phx-key-execute_code
              phx-key="ArrowUp"
              phx-key-navigate_history
              phx-key="ArrowDown"
              phx-key-navigate_history
              class="w-full bg-transparent text-white font-mono resize-none border-none outline-none"
            ><%= @current_input %></textarea>

            <!-- Input Suggestions -->
            <%= if String.length(@current_input) > 2 do %>
              <div class="suggestions mt-2 p-2 bg-gray-700 rounded text-xs">
                <div class="text-gray-400 mb-1">Suggestions:</div>
                <%= for suggestion <- get_input_suggestions(@current_input) do %>
                  <div class="suggestion p-1 hover:bg-gray-600 cursor-pointer rounded">
                    <span class="text-green-400"><%= suggestion.code %></span>
                    <span class="text-gray-400 ml-2">- <%= suggestion.description %></span>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Help Text -->
        <div class="help-text text-xs text-gray-500 mt-2 flex items-center gap-4">
          <span>Press <kbd class="kbd">Enter</kbd> to execute</span>
          <span>Press <kbd class="kbd">Shift+Enter</kbd> for new line</span>
          <span>Use <kbd class="kbd">↑</kbd>/<kbd class="kbd">↓</kbd> for history</span>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp evaluate_elixir_code(code) do
    start_time = System.monotonic_time(:microsecond)

    try do
      # Simulate code evaluation
      result = case String.trim(code) do
        "IO.puts(\"Hello Raxol!\")" ->
          "Hello Raxol!\n:ok"

        "Enum.map([1, 2, 3], &(&1 * 2))" ->
          "[2, 4, 6]"

        "use Raxol.UI, framework: :react" ->
          ":ok"

        ":observer.start()" ->
          ":ok\n# Observer GUI started"

        code ->
          cond do
            String.starts_with?(code, "defmodule") ->
              module_name = extract_module_name(code)
              "{:module, #{module_name}, <<binary>>, :ok}"

            String.contains?(code, "=") ->
              # Variable assignment simulation
              parts = String.split(code, "=", parts: 2)
              if length(parts) == 2 do
                Enum.at(parts, 1) |> String.trim()
              else
                "** (SyntaxError) invalid syntax"
              end

            true ->
              # Generic evaluation
              if String.contains?(code, ["(", ")", "[", "]"]) do
                ":ok"
              else
                code
              end
          end
      end

      execution_time = System.monotonic_time(:microsecond) - start_time

      %{
        output: result,
        status: :success,
        execution_time: execution_time
      }
    rescue
      error ->
        execution_time = System.monotonic_time(:microsecond) - start_time

        %{
          output: "** (#{error.__struct__}) #{Exception.message(error)}",
          status: :error,
          execution_time: execution_time
        }
    end
  end

  defp extract_module_name(code) do
    case Regex.run(~r/defmodule\s+([A-Za-z0-9_.]+)/, code) do
      [_, module_name] -> module_name
      _ -> "UnknownModule"
    end
  end

  defp output_class(status) do
    case status do
      :success -> "text-green-400"
      :error -> "text-red-400"
      :warning -> "text-yellow-400"
      _ -> "text-gray-300"
    end
  end

  defp status_class(status) do
    case status do
      :success -> "text-green-500"
      :error -> "text-red-500"
      :warning -> "text-yellow-500"
      _ -> "text-gray-500"
    end
  end

  defp format_timestamp(timestamp) do
    timestamp
    |> DateTime.to_time()
    |> Time.to_string()
    |> String.slice(0..7)
  end

  defp get_input_suggestions(input) do
    suggestions = [
      %{code: "IO.puts/1", description: "Print to stdout"},
      %{code: "Enum.map/2", description: "Transform list elements"},
      %{code: "Enum.filter/2", description: "Filter list elements"},
      %{code: "String.contains?/2", description: "Check if string contains substring"},
      %{code: "Process.sleep/1", description: "Sleep for milliseconds"},
      %{code: "GenServer.start_link/3", description: "Start GenServer"},
      %{code: "use Raxol.UI", description: "Import Raxol UI framework"},
      %{code: ":observer.start()", description: "Start Erlang Observer"},
      %{code: "Mix.env()", description: "Get current Mix environment"}
    ]

    input_lower = String.downcase(input)

    suggestions
    |> Enum.filter(fn suggestion ->
      String.contains?(String.downcase(suggestion.code), input_lower) ||
      String.contains?(String.downcase(suggestion.description), input_lower)
    end)
    |> Enum.take(5)
  end
end