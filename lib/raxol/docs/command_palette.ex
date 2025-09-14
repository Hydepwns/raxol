defmodule Raxol.Docs.CommandPalette do
  @moduledoc """
  Searchable command palette for Raxol documentation and API exploration.

  Provides fast, fuzzy search across all Raxol modules, functions, components,
  examples, and documentation. Integrates with terminal and web interfaces.
  """

  use GenServer
  require Logger

  alias Raxol.Docs.{Searcher, Formatter}

  @doc_index_file "priv/docs/command_index.json"

  # Client API

  @doc """
  Starts the command palette server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Search across all documentation and APIs.
  """
  def search(query, opts \\ []) do
    GenServer.call(__MODULE__, {:search, query, opts})
  end

  @doc """
  Get command details by ID.
  """
  def get_command(command_id) do
    GenServer.call(__MODULE__, {:get_command, command_id})
  end

  @doc """
  Get all available command categories.
  """
  def get_categories do
    GenServer.call(__MODULE__, :get_categories)
  end

  @doc """
  Execute a command by ID with optional args.
  """
  def execute_command(command_id, args \\ []) do
    GenServer.call(__MODULE__, {:execute_command, command_id, args})
  end

  @doc """
  Rebuild the search index.
  """
  def rebuild_index do
    GenServer.cast(__MODULE__, :rebuild_index)
  end

  @doc """
  Launch the command palette interface.
  """
  def launch(mode \\ :terminal) do
    case mode do
      :terminal -> launch_terminal_interface()
      :web -> launch_web_interface()
      _ -> {:error, "Unknown mode: #{mode}"}
    end
  end

  # Server Implementation

  @impl true
  def init(_opts) do
    index = load_or_build_index()

    state = %{
      index: index,
      last_search: nil,
      search_cache: %{},
      categories: extract_categories(index)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:search, query, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 25)
    category_filter = Keyword.get(opts, :category)

    # Check cache first
    cache_key = {query, limit, category_filter}

    results =
      case Map.get(state.search_cache, cache_key) do
        nil ->
          search_results = perform_search(state.index, query, opts)
          new_cache = Map.put(state.search_cache, cache_key, search_results)

          # Limit cache size
          limited_cache =
            if map_size(new_cache) > 100 do
              new_cache |> Enum.take(50) |> Map.new()
            else
              new_cache
            end

          GenServer.cast(self(), {:update_cache, limited_cache})
          search_results

        cached_results ->
          cached_results
      end

    {:reply, results, %{state | last_search: {query, results}}}
  end

  @impl true
  def handle_call({:get_command, command_id}, _from, state) do
    command = Enum.find(state.index, &(&1.id == command_id))
    {:reply, command, state}
  end

  @impl true
  def handle_call(:get_categories, _from, state) do
    {:reply, state.categories, state}
  end

  @impl true
  def handle_call({:execute_command, command_id, args}, _from, state) do
    case get_command(command_id) do
      nil ->
        {:reply, {:error, "Command not found: #{command_id}"}, state}

      command ->
        result = execute_command_safely(command, args)
        {:reply, result, state}
    end
  end

  @impl true
  def handle_cast(:rebuild_index, state) do
    Logger.info("Rebuilding command palette index...")
    new_index = build_fresh_index()

    new_state = %{
      state
      | index: new_index,
        search_cache: %{},
        categories: extract_categories(new_index)
    }

    save_index(new_index)

    Logger.info(
      "Command palette index rebuilt with #{length(new_index)} commands"
    )

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_cache, new_cache}, state) do
    {:noreply, %{state | search_cache: new_cache}}
  end

  # Private Functions

  defp load_or_build_index do
    case File.read(@doc_index_file) do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms) do
          {:ok, index} ->
            Logger.info("Loaded command index with #{length(index)} commands")
            index

          {:error, _} ->
            Logger.warning("Invalid index file, rebuilding...")
            build_and_save_index()
        end

      {:error, _} ->
        Logger.info("No existing index found, building...")
        build_and_save_index()
    end
  end

  defp build_and_save_index do
    index = build_fresh_index()
    save_index(index)
    index
  end

  defp build_fresh_index do
    Logger.info("Building command palette index...")

    commands =
      []

      # Index Raxol modules
      |> add_module_commands()
      |> add_component_commands()
      |> add_mix_task_commands()
      |> add_example_commands()
      |> add_guide_commands()
      |> add_api_reference_commands()
      |> add_performance_commands()
      |> add_debugging_commands()

    Logger.info("Built index with #{length(commands)} commands")
    commands
  end

  defp add_module_commands(commands) do
    raxol_modules = get_raxol_modules()

    module_commands =
      Enum.flat_map(raxol_modules, fn module ->
        functions = get_module_functions(module)

        Enum.map(functions, fn {func, arity} ->
          %{
            id: "#{module}.#{func}/#{arity}",
            title: "#{inspect(module)}.#{func}/#{arity}",
            description: get_function_description(module, func, arity),
            category: :api,
            type: :function,
            module: module,
            function: func,
            arity: arity,
            tags: ["api", "function", extract_module_domain(module)],
            action: {:show_docs, module, func, arity}
          }
        end)
      end)

    commands ++ module_commands
  end

  defp add_component_commands(commands) do
    components = Raxol.Playground.Catalog.load_components()

    component_commands =
      Enum.map(components, fn component ->
        %{
          id: "component:#{component.id}",
          title: "#{component.name} Component",
          description: component.description,
          category: :component,
          type: :component,
          component: component,
          tags: ["component", component.category | component.tags],
          action: {:preview_component, component.id}
        }
      end)

    commands ++ component_commands
  end

  defp add_mix_task_commands(commands) do
    mix_tasks = [
      %{
        id: "task:test",
        title: "mix raxol.test",
        description: "Run Raxol test suite with optimizations",
        category: :development,
        type: :mix_task,
        tags: ["testing", "development"],
        action: {:run_mix_task, "raxol.test"}
      },
      %{
        id: "task:playground",
        title: "mix raxol.playground",
        description: "Launch interactive component playground",
        category: :development,
        type: :mix_task,
        tags: ["playground", "development"],
        action: {:run_mix_task, "raxol.playground"}
      },
      %{
        id: "task:repl",
        title: "mix raxol.repl",
        description: "Start enhanced REPL with Raxol helpers",
        category: :development,
        type: :mix_task,
        tags: ["repl", "development"],
        action: {:run_mix_task, "raxol.repl"}
      },
      %{
        id: "task:analyze",
        title: "mix raxol.analyze",
        description: "Analyze Raxol application performance",
        category: :performance,
        type: :mix_task,
        tags: ["performance", "analysis"],
        action: {:run_mix_task, "raxol.analyze"}
      }
    ]

    commands ++ mix_tasks
  end

  defp add_example_commands(commands) do
    examples = [
      %{
        id: "example:terminal_editor",
        title: "Terminal Text Editor Example",
        description: "Vi-like terminal text editor implementation",
        category: :example,
        type: :example,
        tags: ["example", "editor", "terminal"],
        action: {:show_example, "terminal_editor"}
      },
      %{
        id: "example:file_browser",
        title: "File Browser Example",
        description: "File system browser with preview",
        category: :example,
        type: :example,
        tags: ["example", "files", "browser"],
        action: {:show_example, "file_browser"}
      },
      %{
        id: "example:dashboard",
        title: "System Monitor Dashboard",
        description: "Real-time system monitoring interface",
        category: :example,
        type: :example,
        tags: ["example", "monitoring", "dashboard"],
        action: {:show_example, "dashboard"}
      },
      %{
        id: "example:chat",
        title: "Chat Application",
        description: "Real-time terminal chat application",
        category: :example,
        type: :example,
        tags: ["example", "chat", "realtime"],
        action: {:show_example, "chat"}
      }
    ]

    commands ++ examples
  end

  defp add_guide_commands(commands) do
    guides = [
      %{
        id: "guide:performance",
        title: "Performance Optimization Guide",
        description: "Best practices for optimizing Raxol applications",
        category: :guide,
        type: :guide,
        tags: ["guide", "performance", "optimization"],
        action: {:show_guide, "performance"}
      },
      %{
        id: "guide:components",
        title: "Custom Component Creation",
        description: "How to create custom Raxol components",
        category: :guide,
        type: :guide,
        tags: ["guide", "components", "development"],
        action: {:show_guide, "components"}
      },
      %{
        id: "guide:accessibility",
        title: "Accessibility Implementation",
        description: "Making Raxol applications accessible",
        category: :guide,
        type: :guide,
        tags: ["guide", "accessibility", "a11y"],
        action: {:show_guide, "accessibility"}
      },
      %{
        id: "guide:migration",
        title: "Multi-Framework Migration",
        description: "Migrating between UI frameworks",
        category: :guide,
        type: :guide,
        tags: ["guide", "migration", "frameworks"],
        action: {:show_guide, "migration"}
      }
    ]

    commands ++ guides
  end

  defp add_api_reference_commands(commands) do
    api_refs = [
      %{
        id: "api:ui",
        title: "Raxol.UI API Reference",
        description: "Complete UI framework API documentation",
        category: :reference,
        type: :api_reference,
        tags: ["api", "ui", "reference"],
        action: {:show_api_reference, "ui"}
      },
      %{
        id: "api:terminal",
        title: "Terminal API Reference",
        description: "Terminal emulation and control APIs",
        category: :reference,
        type: :api_reference,
        tags: ["api", "terminal", "reference"],
        action: {:show_api_reference, "terminal"}
      },
      %{
        id: "api:components",
        title: "Components API Reference",
        description: "Built-in component library reference",
        category: :reference,
        type: :api_reference,
        tags: ["api", "components", "reference"],
        action: {:show_api_reference, "components"}
      }
    ]

    commands ++ api_refs
  end

  defp add_performance_commands(commands) do
    perf_commands = [
      %{
        id: "perf:benchmark",
        title: "Run Performance Benchmarks",
        description: "Execute comprehensive performance benchmarks",
        category: :performance,
        type: :action,
        tags: ["performance", "benchmark"],
        action: {:run_benchmarks}
      },
      %{
        id: "perf:profile",
        title: "Profile Application",
        description: "Profile memory and CPU usage",
        category: :performance,
        type: :action,
        tags: ["performance", "profiling"],
        action: {:start_profiling}
      },
      %{
        id: "perf:optimize",
        title: "Optimization Suggestions",
        description: "Get performance optimization recommendations",
        category: :performance,
        type: :action,
        tags: ["performance", "optimization"],
        action: {:show_optimization_tips}
      }
    ]

    commands ++ perf_commands
  end

  defp add_debugging_commands(commands) do
    debug_commands = [
      %{
        id: "debug:observer",
        title: "Start Observer",
        description: "Launch Erlang Observer for system inspection",
        category: :debugging,
        type: :action,
        tags: ["debugging", "observer"],
        action: {:start_observer}
      },
      %{
        id: "debug:logs",
        title: "View Application Logs",
        description: "Show recent application logs",
        category: :debugging,
        type: :action,
        tags: ["debugging", "logs"],
        action: {:show_logs}
      },
      %{
        id: "debug:trace",
        title: "Enable Function Tracing",
        description: "Start function call tracing",
        category: :debugging,
        type: :action,
        tags: ["debugging", "tracing"],
        action: {:start_tracing}
      }
    ]

    commands ++ debug_commands
  end

  defp perform_search(index, query, opts) do
    limit = Keyword.get(opts, :limit, 25)
    category_filter = Keyword.get(opts, :category)

    filtered_index =
      case category_filter do
        nil -> index
        category -> Enum.filter(index, &(&1.category == category))
      end

    if String.trim(query) == "" do
      filtered_index
      |> Enum.take(limit)
      |> add_search_scores(1.0)
    else
      Searcher.fuzzy_search(filtered_index, query, limit)
    end
  end

  defp add_search_scores(results, score) do
    Enum.map(results, &Map.put(&1, :score, score))
  end

  defp execute_command_safely(command, args) do
    try do
      case command.action do
        {:show_docs, module, function, arity} ->
          show_function_docs(module, function, arity)

        {:preview_component, component_id} ->
          Raxol.Playground.select_component(component_id)

        {:run_mix_task, task_name} ->
          run_mix_task_safe(task_name, args)

        {:show_example, example_id} ->
          show_example(example_id)

        {:show_guide, guide_id} ->
          show_guide(guide_id)

        {:show_api_reference, api_id} ->
          show_api_reference(api_id)

        {:run_benchmarks} ->
          run_performance_benchmarks()

        {:start_profiling} ->
          start_application_profiling()

        {:show_optimization_tips} ->
          show_optimization_tips()

        {:start_observer} ->
          case Code.ensure_loaded(:observer) do
            {:module, :observer} ->
              apply(:observer, :start, [])
              {:ok, "Observer started"}

            _ ->
              {:error, "Observer is not available in this environment"}
          end

        {:show_logs} ->
          show_recent_logs()

        {:start_tracing} ->
          enable_function_tracing()

        _ ->
          {:error, "Unknown command action: #{inspect(command.action)}"}
      end
    rescue
      error ->
        Logger.error("Command execution failed: #{inspect(error)}")
        {:error, "Command failed: #{Exception.message(error)}"}
    end
  end

  defp save_index(index) do
    File.mkdir_p!(Path.dirname(@doc_index_file))
    content = Jason.encode!(index, pretty: true)
    File.write!(@doc_index_file, content)
  end

  defp extract_categories(index) do
    index
    |> Enum.map(& &1.category)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp get_raxol_modules do
    :code.all_loaded()
    |> Enum.filter(fn {module, _} ->
      module_name = Atom.to_string(module)
      String.starts_with?(module_name, "Elixir.Raxol.")
    end)
    |> Enum.map(fn {module, _} -> module end)
    |> Enum.reject(&is_test_module?/1)
  end

  defp is_test_module?(module) do
    module_name = Atom.to_string(module)

    String.contains?(module_name, "Test") or
      String.contains?(module_name, "Mock")
  end

  defp get_module_functions(module) do
    try do
      module.__info__(:functions)
      |> Enum.reject(fn {func, _arity} ->
        func_name = Atom.to_string(func)

        String.starts_with?(func_name, "__") or
          func in [:module_info, :behaviour_info]
      end)
    rescue
      _ -> []
    end
  end

  defp get_function_description(module, function, arity) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, _, _, docs} ->
        case Enum.find(docs, fn {{type, name, ar}, _, _, _, _} ->
               type == :function and name == function and ar == arity
             end) do
          {_, _, _, %{"en" => doc}, _} when is_binary(doc) ->
            doc |> String.split("\n") |> List.first() |> String.trim()

          _ ->
            "Function #{function}/#{arity}"
        end

      _ ->
        "Function #{function}/#{arity}"
    end
  end

  defp extract_module_domain(module) do
    module_name = Atom.to_string(module)

    cond do
      String.contains?(module_name, ".UI.") -> "ui"
      String.contains?(module_name, ".Terminal.") -> "terminal"
      String.contains?(module_name, ".Component") -> "component"
      String.contains?(module_name, ".Core.") -> "core"
      true -> "other"
    end
  end

  # Terminal Interface

  defp launch_terminal_interface do
    IO.puts("""
    #{IO.ANSI.cyan()}╔══════════════════════════════════════════════════════╗
    ║              Raxol Command Palette 🎯                ║
    ╚══════════════════════════════════════════════════════╝#{IO.ANSI.reset()}

    Type to search. Press Enter to execute, Ctrl+C to exit.
    """)

    terminal_search_loop()
  end

  defp terminal_search_loop do
    query =
      IO.gets("#{IO.ANSI.green()}search>#{IO.ANSI.reset()} ") |> String.trim()

    case query do
      "exit" ->
        :ok

      "quit" ->
        :ok

      "" ->
        terminal_search_loop()

      _ ->
        results = search(query, limit: 10)
        display_terminal_results(results)

        case IO.gets("Execute command [1-#{length(results)}] or press Enter: ")
             |> String.trim() do
          "" ->
            terminal_search_loop()

          num_str ->
            case Integer.parse(num_str) do
              {num, ""} when num >= 1 and num <= length(results) ->
                command = Enum.at(results, num - 1)
                execute_terminal_command(command)
                terminal_search_loop()

              _ ->
                IO.puts("Invalid selection")
                terminal_search_loop()
            end
        end
    end
  end

  defp display_terminal_results(results) do
    IO.puts("\n#{IO.ANSI.bright()}Search Results:#{IO.ANSI.reset()}")

    results
    |> Enum.with_index(1)
    |> Enum.each(fn {result, index} ->
      score_indicator = get_score_indicator(Map.get(result, :score, 1.0))
      category_color = get_category_color(result.category)

      IO.puts(
        "#{score_indicator} #{IO.ANSI.yellow()}[#{index}]#{IO.ANSI.reset()} #{result.title}"
      )

      IO.puts(
        "    #{category_color}#{result.category}#{IO.ANSI.reset()} • #{result.description}"
      )
    end)

    IO.puts("")
  end

  defp get_score_indicator(score) when score > 0.8, do: "🎯"
  defp get_score_indicator(score) when score > 0.6, do: "✅"
  defp get_score_indicator(score) when score > 0.4, do: "⚡"
  defp get_score_indicator(_), do: "💡"

  defp get_category_color(:api), do: IO.ANSI.blue()
  defp get_category_color(:component), do: IO.ANSI.green()
  defp get_category_color(:example), do: IO.ANSI.magenta()
  defp get_category_color(:guide), do: IO.ANSI.cyan()
  defp get_category_color(:performance), do: IO.ANSI.red()
  defp get_category_color(_), do: IO.ANSI.light_black()

  defp execute_terminal_command(command) do
    IO.puts("Executing: #{command.title}")

    case execute_command(command.id) do
      {:ok, result} when is_binary(result) ->
        IO.puts(result)

      {:ok, _} ->
        IO.puts("✅ Command executed successfully")

      {:error, reason} ->
        IO.puts("❌ Error: #{reason}")
    end
  end

  # Web Interface

  defp launch_web_interface do
    # This would integrate with the existing playground web interface
    # to add command palette functionality

    Mix.shell().info("Command palette available in web playground at /docs")
    Raxol.Playground.launch(web: true)
  end

  # Placeholder implementations for command actions

  defp show_function_docs(module, function, arity) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, _, _, docs} ->
        case Enum.find(docs, fn {{type, name, ar}, _, _, _, _} ->
               type == :function and name == function and ar == arity
             end) do
          {_, _, _, doc_content, _} ->
            formatted =
              Formatter.format_function_docs(
                module,
                function,
                arity,
                doc_content
              )

            {:ok, formatted}

          _ ->
            {:ok,
             "No documentation found for #{inspect(module)}.#{function}/#{arity}"}
        end

      _ ->
        {:ok, "No documentation available for #{inspect(module)}"}
    end
  end

  defp run_mix_task_safe(task_name, _args) do
    {:ok, "Would run: mix #{task_name}"}
  end

  defp show_example(example_id) do
    {:ok, "Would show example: #{example_id}"}
  end

  defp show_guide(guide_id) do
    {:ok, "Would show guide: #{guide_id}"}
  end

  defp show_api_reference(api_id) do
    {:ok, "Would show API reference: #{api_id}"}
  end

  defp run_performance_benchmarks do
    {:ok, "Performance benchmarks started"}
  end

  defp start_application_profiling do
    {:ok, "Application profiling enabled"}
  end

  defp show_optimization_tips do
    tips = """
    🚀 Performance Optimization Tips:

    • Use binary pattern matching for ANSI parsing
    • Cache expensive calculations with ETS
    • Minimize GenServer calls in hot paths
    • Use tail recursion for large datasets
    • Profile with :fprof and :eprof
    • Consider process pooling for concurrent work
    """

    {:ok, tips}
  end

  defp show_recent_logs do
    {:ok, "Recent application logs would be shown here"}
  end

  defp enable_function_tracing do
    {:ok, "Function tracing enabled"}
  end
end
