defmodule Raxol.Extensions.VSCodeBackend do
  @moduledoc """
  Backend handler for the VS Code extension.

  This module provides the Elixir-side implementation for communicating
  with the VS Code extension, handling requests for AI features, performance
  analysis, and component management.
  """

  use GenServer

  alias Raxol.AI.{ContentGeneration, PerformanceOptimization}
  require Logger

  @json_start_marker "RAXOL-JSON-BEGIN"
  @json_end_marker "RAXOL-JSON-END"

  defmodule State do
    @moduledoc false
    defstruct [:mode, :extension_pid, :active_requests, :capabilities]

    def new do
      %__MODULE__{
        mode: System.get_env("RAXOL_MODE") || "standalone",
        extension_pid: nil,
        active_requests: %{},
        capabilities:
          MapSet.new([
            :ai_content_generation,
            :performance_analysis,
            :component_analysis,
            :code_completion,
            :optimization_suggestions
          ])
      }
    end
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    state = State.new()

    if state.mode == "vscode_ext" do
      Logger.info("[VSCodeBackend] Starting in VS Code extension mode")
      # Start listening for stdin messages from the extension
      Task.start_link(&listen_for_messages/0)
      send_capabilities(state.capabilities)
    end

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:handle_message, message}, state) do
    # handle_extension_message always returns {:ok, state}
    {:ok, new_state} = handle_extension_message(message, state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:send_response, request_id, response}, state) do
    send_json_message(%{
      type: "response",
      request_id: request_id,
      payload: response
    })

    # Remove from active requests
    active_requests = Map.delete(state.active_requests, request_id)
    {:noreply, %{state | active_requests: active_requests}}
  end

  # Public API

  @doc """
  Handles a code completion request from the VS Code extension.
  """
  def handle_completion_request(input, context) do
    case ContentGeneration.suggest_text(input, context: context) do
      {:ok, suggestions} ->
        {:ok, %{suggestions: suggestions, context: context}}

      error ->
        error
    end
  end

  @doc """
  Handles a performance analysis request from the VS Code extension.
  """
  def handle_performance_analysis(code, component_name, metrics \\ %{}) do
    case PerformanceOptimization.get_ai_optimization_analysis(
           component_name,
           code,
           metrics
         ) do
      {:ok, analysis} ->
        {:ok,
         %{
           component: component_name,
           analysis: analysis,
           suggestions: extract_suggestions(analysis)
         }}

      error ->
        error
    end
  end

  @doc """
  Handles a component analysis request from the VS Code extension.
  """
  def handle_component_analysis(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, ast} <- Code.string_to_quoted(content) do
      analysis = %{
        module_name: extract_module_name(ast),
        functions: extract_functions(ast),
        dependencies: extract_dependencies(ast),
        complexity_score: calculate_complexity(ast),
        suggestions: generate_component_suggestions(ast)
      }

      {:ok, analysis}
    else
      {:error, reason} ->
        {:error, "Failed to analyze component: #{inspect(reason)}"}
    end
  end

  @doc """
  Lists available components in the project.
  """
  def list_components do
    try do
      # Find all .ex files that look like components
      components =
        Path.wildcard("lib/**/*.ex")
        |> Enum.filter(&component_file?/1)
        |> Enum.map(&analyze_component_file/1)
        |> Enum.filter(& &1)

      {:ok, components}
    rescue
      error -> {:error, "Failed to list components: #{inspect(error)}"}
    end
  end

  # Private functions

  defp listen_for_messages do
    case IO.read(:stdio, :line) do
      :eof ->
        Logger.info("[VSCodeBackend] EOF received, stopping message listener")
        :ok

      {:error, reason} ->
        Logger.error(
          "[VSCodeBackend] Error reading from stdin: #{inspect(reason)}"
        )

        :error

      data ->
        case Jason.decode(String.trim(data)) do
          {:ok, message} ->
            GenServer.cast(__MODULE__, {:handle_message, message})

          {:error, _} ->
            Logger.warning(
              "[VSCodeBackend] Invalid JSON received: #{inspect(data)}"
            )
        end

        listen_for_messages()
    end
  end

  defp handle_extension_message(
         %{"type" => "request", "id" => request_id} = message,
         state
       ) do
    # Store the request
    active_requests = Map.put(state.active_requests, request_id, message)
    new_state = %{state | active_requests: active_requests}

    # Process the request asynchronously
    Task.start(fn ->
      response = process_request(message)
      GenServer.cast(__MODULE__, {:send_response, request_id, response})
    end)

    {:ok, new_state}
  end

  defp handle_extension_message(%{"type" => "shutdown"}, state) do
    Logger.info("[VSCodeBackend] Shutdown requested by extension")
    System.stop()
    {:ok, state}
  end

  defp handle_extension_message(message, state) do
    Logger.info("[VSCodeBackend] Received message: #{inspect(message)}")
    {:ok, state}
  end

  defp process_request(%{"action" => "complete", "payload" => payload}) do
    input = Map.get(payload, "input", "")
    context = Map.get(payload, "context", %{})

    case handle_completion_request(input, context) do
      {:ok, result} -> %{status: "success", data: result}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end

  defp process_request(%{
         "action" => "analyze_performance",
         "payload" => payload
       }) do
    code = Map.get(payload, "code", "")
    component_name = Map.get(payload, "component_name", "unknown")
    metrics = Map.get(payload, "metrics", %{})

    case handle_performance_analysis(code, component_name, metrics) do
      {:ok, result} -> %{status: "success", data: result}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end

  defp process_request(%{"action" => "analyze_component", "payload" => payload}) do
    file_path = Map.get(payload, "file_path", "")

    case handle_component_analysis(file_path) do
      {:ok, result} -> %{status: "success", data: result}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end

  defp process_request(%{"action" => "list_components"}) do
    case list_components() do
      {:ok, result} -> %{status: "success", data: result}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end

  defp process_request(%{"action" => action}) do
    %{status: "error", error: "Unknown action: #{action}"}
  end

  defp send_capabilities(capabilities) do
    send_json_message(%{
      type: "capabilities",
      payload: %{
        capabilities: MapSet.to_list(capabilities),
        ai_provider: Application.get_env(:raxol, :ai_provider, :mock),
        version: Application.spec(:raxol, :vsn)
      }
    })
  end

  defp send_json_message(message) do
    json = Jason.encode!(message)
    IO.puts("#{@json_start_marker}#{json}#{@json_end_marker}")
  end

  defp extract_suggestions(analysis) do
    Enum.map(analysis, fn item ->
      %{
        type: Map.get(item, :type, :general),
        description: Map.get(item, :description, ""),
        suggestion: Map.get(item, :suggestion, ""),
        severity: Map.get(item, :severity, :medium)
      }
    end)
  end

  defp component_file?(file_path) do
    content = File.read!(file_path)

    String.contains?(content, ["defmodule", "@behaviour", "use GenServer"]) and
      not String.contains?(file_path, ["test/", "_test.exs"])
  end

  defp analyze_component_file(file_path) do
    try do
      content = File.read!(file_path)
      {:ok, ast} = Code.string_to_quoted(content)

      %{
        file_path: file_path,
        module_name: extract_module_name(ast),
        type: determine_component_type(ast),
        functions: length(extract_functions(ast)),
        complexity: calculate_complexity(ast)
      }
    rescue
      _ -> nil
    end
  end

  defp extract_module_name(ast) do
    case ast do
      {:defmodule, _, [{:__aliases__, _, module_parts}, _]} ->
        Enum.join(module_parts, ".")

      _ ->
        "Unknown"
    end
  end

  defp extract_functions(ast) do
    {functions, _} =
      Macro.prewalk(ast, [], fn
        {:def, _, [{name, _, _} | _]}, acc -> {ast, [name | acc]}
        {:defp, _, [{name, _, _} | _]}, acc -> {ast, [name | acc]}
        node, acc -> {node, acc}
      end)

    Enum.uniq(functions)
  end

  defp extract_dependencies(ast) do
    {deps, _} =
      Macro.prewalk(ast, [], fn
        {:alias, _, [{:__aliases__, _, module_parts}]}, acc ->
          {ast, [Enum.join(module_parts, ".") | acc]}

        {:import, _, [{:__aliases__, _, module_parts}]}, acc ->
          {ast, [Enum.join(module_parts, ".") | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.uniq(deps)
  end

  defp calculate_complexity(ast) do
    {_, complexity} =
      Macro.prewalk(ast, 0, fn
        {:if, _, _}, acc -> {ast, acc + 1}
        {:case, _, _}, acc -> {ast, acc + 2}
        {:cond, _, _}, acc -> {ast, acc + 2}
        {:with, _, _}, acc -> {ast, acc + 1}
        {:try, _, _}, acc -> {ast, acc + 2}
        node, acc -> {node, acc}
      end)

    complexity
  end

  defp determine_component_type(ast) do
    content = Macro.to_string(ast)

    cond do
      String.contains?(content, "GenServer") -> :genserver
      String.contains?(content, "@behaviour") -> :behaviour
      String.contains?(content, "Supervisor") -> :supervisor
      String.contains?(content, "Application") -> :application
      true -> :module
    end
  end

  defp generate_component_suggestions(ast) do
    complexity = calculate_complexity(ast)
    functions = extract_functions(ast)

    suggestions = []

    suggestions =
      if complexity > 10 do
        ["Consider breaking down complex functions" | suggestions]
      else
        suggestions
      end

    suggestions =
      if length(functions) > 20 do
        ["Large module - consider splitting into smaller modules" | suggestions]
      else
        suggestions
      end

    if suggestions == [] do
      ["Component looks well-structured"]
    else
      suggestions
    end
  end
end
