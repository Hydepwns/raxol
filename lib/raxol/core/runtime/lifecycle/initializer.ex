defmodule Raxol.Core.Runtime.Lifecycle.Initializer do
  @moduledoc """
  Component startup sequence for the Raxol application lifecycle.
  Extracted from Lifecycle to reduce file size.
  """

  alias Raxol.Core.CompilerState
  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Log
  alias Raxol.Core.Runtime.Plugins.PluginManager, as: Manager

  @doc """
  Initializes all components in order: registry table, plugin manager, app model,
  dispatcher, terminal driver, rendering engine.
  Returns `{:ok, registry_table, pm_pid, model, dispatcher_pid, driver_pid, engine_pid}`
  or `{:error, reason, cleanup_fun}`.
  """
  def initialize_all(app_module, options) do
    environment = Keyword.get(options, :environment, :terminal)

    with {:ok, registry_table} <- initialize_registry_table(app_module),
         {:ok, pm_pid} <- start_plugin_manager(options, environment),
         {:ok, initialized_model} <-
           initialize_app_model(app_module, get_initial_model_args(options)),
         {:ok, dispatcher_pid} <-
           start_dispatcher(
             app_module,
             initialized_model,
             options,
             pm_pid,
             registry_table
           ),
         {:ok, driver_pid} <- maybe_start_driver(dispatcher_pid, environment),
         {:ok, rendering_engine_pid} <-
           start_rendering_engine(app_module, dispatcher_pid, options) do
      GenServer.cast(
        dispatcher_pid,
        {:set_rendering_engine, rendering_engine_pid}
      )

      {:ok, registry_table, pm_pid, initialized_model, dispatcher_pid,
       driver_pid, rendering_engine_pid}
    end
  end

  @doc "Starts the CodeReloader in dev mode; returns nil otherwise."
  def maybe_start_code_reloader(lifecycle_pid) do
    if Code.ensure_loaded?(Mix) and Mix.env() == :dev do
      case Raxol.Dev.CodeReloader.start_link(lifecycle_pid) do
        {:ok, pid} -> pid
        _ -> nil
      end
    else
      nil
    end
  rescue
    e ->
      Log.debug("[Initializer] CodeReloader unavailable: #{Exception.message(e)}")
      nil
  end

  @doc "Detects actual terminal size, falling back to options then 80x24."
  def detect_terminal_size(options) do
    default_w = Keyword.get(options, :width, 80)
    default_h = Keyword.get(options, :height, 24)

    case {:io.columns(), :io.rows()} do
      {{:ok, cols}, {:ok, rows}} when cols > 0 and rows > 0 ->
        {cols, rows}

      _ ->
        case Raxol.Terminal.Driver.Stty.size() do
          {:ok, cols, rows} -> {cols, rows}
          :error -> {default_w, default_h}
        end
    end
  end

  # --- private ---

  defp initialize_registry_table(app_module) do
    registry_table_name =
      Module.concat(CommandRegistryTable, Atom.to_string(app_module))

    case CompilerState.ensure_table(registry_table_name, [
           :set,
           :protected,
           :named_table,
           {:read_concurrency, true}
         ]) do
      :ok ->
        {:ok, registry_table_name}

      {:error, _reason} ->
        {:error, :registry_table_creation_failed,
         fn -> CompilerState.safe_delete_table(registry_table_name) end}
    end
  end

  defp start_plugin_manager(_options, :agent), do: {:ok, nil}

  defp start_plugin_manager(options, _environment) do
    plugin_manager_opts = Keyword.get(options, :plugin_manager_opts, [])

    case Manager.start_link(plugin_manager_opts) do
      {:ok, pm_pid} ->
        Log.info_with_context(
          "[Lifecycle.Initializer] PluginManager started with PID: #{inspect(pm_pid)}"
        )

        {:ok, pm_pid}

      {:error, reason} ->
        {:error, {:plugin_manager_start_failed, reason}, fn -> :ok end}
    end
  end

  defp get_initial_model_args(options) do
    %{
      width: Keyword.get(options, :width, 80),
      height: Keyword.get(options, :height, 24),
      options: options
    }
  end

  defp initialize_app_model(app_module, initial_model_args) do
    if function_exported?(app_module, :init, 1) do
      call_app_init(app_module, initial_model_args)
    else
      Log.info(
        "[Lifecycle.Initializer] #{inspect(app_module)}.init/1 not exported. Using empty model."
      )

      {:ok, %{}}
    end
  end

  defp call_app_init(app_module, initial_model_args) do
    case app_module.init(initial_model_args) do
      {:ok, model} ->
        {:ok, model}

      {_, model} ->
        Log.warning_with_context(
          "[Lifecycle.Initializer] #{inspect(app_module)}.init returned a tuple, using model: #{inspect(model)}",
          %{}
        )

        {:ok, model}

      model when is_map(model) ->
        Log.info(
          "[Lifecycle.Initializer] #{inspect(app_module)}.init returned a map directly: #{inspect(model)}"
        )

        {:ok, model}

      _ ->
        Log.warning_with_context(
          "[Lifecycle.Initializer] #{inspect(app_module)}.init did not return {:ok, model} or a map. Using empty model.",
          %{}
        )

        {:ok, %{}}
    end
  end

  defp start_dispatcher(
         app_module,
         initialized_model,
         options,
         pm_pid,
         registry_table
       ) do
    dispatcher_initial_state = %{
      app_module: app_module,
      model: initialized_model,
      width: Keyword.get(options, :width, 80),
      height: Keyword.get(options, :height, 24),
      debug_mode:
        Keyword.get(options, :debug_mode, Keyword.get(options, :debug, false)),
      plugin_manager: pm_pid,
      command_registry_table: registry_table
    }

    environment = Keyword.get(options, :environment, :terminal)
    dispatcher_opts = if environment == :agent, do: [name: nil], else: []

    case Dispatcher.start_link(
           self(),
           dispatcher_initial_state,
           dispatcher_opts
         ) do
      {:ok, dispatcher_pid} ->
        {:ok, dispatcher_pid}

      {:error, reason} ->
        cleanup =
          if pm_pid, do: fn -> Manager.stop(pm_pid) end, else: fn -> :ok end

        {:error, {:dispatcher_start_failed, reason}, cleanup}
    end
  end

  defp maybe_start_driver(_dispatcher_pid, :liveview), do: {:ok, nil}
  defp maybe_start_driver(_dispatcher_pid, :ssh), do: {:ok, nil}
  defp maybe_start_driver(_dispatcher_pid, :agent), do: {:ok, nil}

  defp maybe_start_driver(dispatcher_pid, _environment) do
    case Raxol.Terminal.Driver.start_link(dispatcher_pid: dispatcher_pid) do
      {:ok, driver_pid} ->
        Log.info_with_context(
          "[Lifecycle.Initializer] Terminal Driver started with PID: #{inspect(driver_pid)}"
        )

        {:ok, driver_pid}

      {:error, reason} ->
        Log.warning_with_context(
          "[Lifecycle.Initializer] Terminal Driver failed to start: #{inspect(reason)}. Continuing without driver.",
          %{}
        )

        {:ok, nil}
    end
  end

  defp start_rendering_engine(app_module, dispatcher_pid, options) do
    {actual_w, actual_h} = detect_terminal_size(options)

    engine_opts =
      [
        app_module: app_module,
        dispatcher_pid: dispatcher_pid,
        width: actual_w,
        height: actual_h,
        environment: Keyword.get(options, :environment, :terminal)
      ]
      |> maybe_add_opt(:liveview_topic, Keyword.get(options, :liveview_topic))
      |> maybe_add_opt(:io_writer, Keyword.get(options, :io_writer))

    case Raxol.Core.Runtime.Rendering.Engine.start_link(engine_opts) do
      {:ok, engine_pid} ->
        Log.info_with_context(
          "[Lifecycle.Initializer] Rendering Engine started with PID: #{inspect(engine_pid)}"
        )

        {:ok, engine_pid}

      {:error, reason} ->
        Log.warning_with_context(
          "[Lifecycle.Initializer] Rendering Engine failed to start: #{inspect(reason)}. Continuing without rendering engine.",
          %{}
        )

        {:ok, nil}
    end
  end

  defp maybe_add_opt(opts, _key, nil), do: opts
  defp maybe_add_opt(opts, key, value), do: Keyword.put(opts, key, value)
end
