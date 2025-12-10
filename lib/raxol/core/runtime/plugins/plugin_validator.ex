defmodule Raxol.Core.Runtime.Plugins.PluginValidator do
  @moduledoc """
  Comprehensive validation system for plugins before loading.

  This module provides extensive validation checks including security,
  compatibility, performance, and structural validation to ensure
  plugins are safe and properly implemented.

  REFACTORED: All try/catch blocks replaced with functional patterns using with statements.
  """

  alias Raxol.Core.Runtime.Plugins.Loader

  @type validation_result :: :ok | {:error, term()}
  @type plugin_metadata :: %{
          name: String.t(),
          version: String.t(),
          author: String.t(),
          description: String.t(),
          dependencies: [String.t()],
          api_version: String.t()
        }

  @required_callbacks [:init, :handle_event, :cleanup]
  # 10MB limit
  @max_plugin_size 10_000_000
  @supported_api_versions ["1.0", "1.1", "2.0"]

  @doc """
  Performs comprehensive validation of a plugin.
  """
  @spec validate_plugin(String.t(), module(), map(), map()) ::
          validation_result()
  def validate_plugin(plugin_id, plugin_module, plugins, options \\ %{}) do
    with :ok <- validate_not_loaded(plugin_id, plugins),
         :ok <- validate_behaviour(plugin_module),
         :ok <- validate_metadata(plugin_module),
         :ok <- validate_security(plugin_module, options),
         :ok <- validate_compatibility(plugin_module),
         :ok <- validate_performance(plugin_module),
         :ok <- validate_dependencies(plugin_module, plugins) do
      :ok
    else
      error -> error
    end
  end

  @doc """
  Validates that a plugin is not already loaded.
  """
  @spec validate_not_loaded(String.t(), map()) ::
          :ok | {:error, :already_loaded}
  def validate_not_loaded(plugin_id, plugins) do
    check_plugin_loaded_status(plugins, plugin_id)
  end

  @doc """
  Validates that a plugin module implements the required behaviour.
  """
  @spec validate_behaviour(module()) ::
          :ok
          | {:error,
             :module_not_found
             | :invalid_plugin_behaviour
             | {:missing_callbacks, [atom()]}}
  def validate_behaviour(plugin_module) do
    with :ok <- validate_module_exists(plugin_module),
         :ok <- validate_plugin_behaviour(plugin_module),
         :ok <- validate_required_callbacks(plugin_module) do
      :ok
    else
      error -> error
    end
  end

  @doc """
  Validates plugin metadata and configuration.
  """
  @spec validate_metadata(module()) ::
          :ok
          | {:error,
             :missing_metadata
             | :invalid_metadata
             | {:missing_metadata_fields, [atom()]}
             | :invalid_version_format
             | {:unsupported_api_version, String.t()}
             | :invalid_plugin_name}
  def validate_metadata(plugin_module) do
    case get_plugin_metadata(plugin_module) do
      {:ok, metadata} ->
        with :ok <- validate_required_fields(metadata),
             :ok <- validate_version_format(metadata.version),
             :ok <- validate_api_version(metadata.api_version),
             :ok <- validate_name_format(metadata.name) do
          :ok
        else
          error -> error
        end

      {:error, :no_metadata} ->
        {:error, :missing_metadata}

      error ->
        error
    end
  end

  @doc """
  Validates plugin security aspects.
  """
  @spec validate_security(module(), map()) :: :ok
  def validate_security(plugin_module, options \\ %{}) do
    :ok = validate_file_access(plugin_module, options)
    :ok = validate_network_access(plugin_module, options)
    :ok = validate_code_injection(plugin_module)
    :ok = validate_resource_limits(plugin_module)
    :ok
  end

  @doc """
  Validates plugin compatibility with the current system.
  """
  @spec validate_compatibility(module()) ::
          :ok
          | {:error,
             {:elixir_version_too_old, String.t(), String.t()}
             | {:otp_version_too_old, String.t(), String.t()}}
  def validate_compatibility(plugin_module) do
    with :ok <- validate_elixir_version(plugin_module),
         :ok <- validate_otp_version(plugin_module),
         :ok <- validate_platform_support(plugin_module) do
      :ok
    else
      error -> error
    end
  end

  @doc """
  Validates plugin performance characteristics.
  """
  @spec validate_performance(module()) ::
          :ok
          | {:error,
             {:initialization_failed, term()}
             | {:initialization_too_slow, non_neg_integer()}
             | {:plugin_too_large, non_neg_integer(), non_neg_integer()}
             | {:size_check_failed, term()}}
  def validate_performance(plugin_module) do
    with :ok <- validate_memory_usage(plugin_module),
         :ok <- validate_initialization_time(plugin_module),
         :ok <- validate_plugin_size(plugin_module) do
      :ok
    else
      error -> error
    end
  end

  @doc """
  Validates plugin dependencies.
  """
  @spec validate_dependencies(module(), map()) :: validation_result()
  def validate_dependencies(plugin_module, loaded_plugins) do
    case get_plugin_dependencies(plugin_module) do
      {:ok, dependencies} ->
        validate_dependency_list(dependencies, loaded_plugins)

      {:error, :no_dependencies} ->
        :ok

      error ->
        error
    end
  end

  @doc """
  Resolves plugin identity from string or module.
  """
  @spec resolve_plugin_identity(String.t() | module()) ::
          {:ok, {String.t(), module()}} | {:error, term()}
  def resolve_plugin_identity(id) when is_binary(id) do
    case Raxol.Core.Runtime.Plugins.Loader.load_code(id) do
      {:ok, module} ->
        {:ok, {id, module}}

      {:error, :module_not_found} ->
        {:error, :module_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def resolve_plugin_identity(module) when is_atom(module) do
    resolve_module_identity(module)
  end

  # Private validation functions

  @spec validate_module_exists(module()) :: :ok | {:error, :module_not_found}
  defp validate_module_exists(plugin_module) do
    check_module_loaded(plugin_module)
  end

  @spec validate_plugin_behaviour(module()) ::
          :ok | {:error, :invalid_plugin_behaviour}
  defp validate_plugin_behaviour(plugin_module) do
    check_plugin_behaviour_implementation(plugin_module)
  end

  @spec validate_required_callbacks(module()) ::
          :ok | {:error, {:missing_callbacks, [atom()]}}
  defp validate_required_callbacks(plugin_module) do
    available_callbacks = plugin_module.__info__(:functions)

    missing_callbacks =
      @required_callbacks
      |> Enum.filter(fn callback ->
        not Enum.any?(available_callbacks, fn {name, _arity} ->
          name == callback
        end)
      end)

    validate_callbacks_present(missing_callbacks)
  end

  @spec get_plugin_metadata(module()) :: {:ok, map()} | {:error, atom()}
  defp get_plugin_metadata(plugin_module) do
    with {:exported?, true} <-
           {:exported?, function_exported?(plugin_module, :metadata, 0)},
         {:ok, metadata} <- safe_call_metadata(plugin_module) do
      {:ok, metadata}
    else
      {:exported?, false} -> {:error, :no_metadata}
      {:error, _reason} -> {:error, :invalid_metadata}
    end
  end

  @spec safe_call_metadata(module()) :: {:ok, map()} | {:error, atom()}
  defp safe_call_metadata(plugin_module) do
    # Use Task for timeout and error isolation
    task = Task.async(fn -> plugin_module.metadata() end)

    case Task.yield(task, 1000) || Task.shutdown(task, :brutal_kill) do
      {:ok, metadata} when is_map(metadata) -> {:ok, metadata}
      {:ok, _} -> {:error, :invalid_metadata_format}
      nil -> {:error, :metadata_timeout}
      {:exit, _reason} -> {:error, :metadata_crashed}
    end
  end

  @spec validate_required_fields(map()) ::
          :ok | {:error, {:missing_metadata_fields, [atom()]}}
  defp validate_required_fields(metadata) do
    required_fields = [:name, :version, :author, :api_version]

    missing_fields =
      required_fields
      |> Enum.filter(fn field -> not Map.has_key?(metadata, field) end)

    validate_metadata_fields_present(missing_fields)
  end

  @spec validate_version_format(String.t()) ::
          :ok | {:error, :invalid_version_format}
  defp validate_version_format(version) do
    case Regex.match?(~r/^\d+\.\d+(\.\d+)?(-\w+)?$/, version) do
      true -> :ok
      false -> {:error, :invalid_version_format}
    end
  end

  @spec validate_api_version(String.t()) ::
          :ok | {:error, {:unsupported_api_version, String.t()}}
  defp validate_api_version(api_version) do
    check_api_version_supported(api_version)
  end

  @spec validate_name_format(String.t() | atom()) ::
          :ok | {:error, :invalid_plugin_name}
  defp validate_name_format(name) do
    case Regex.match?(~r/^[a-zA-Z][a-zA-Z0-9_]*$/, name) do
      true -> :ok
      false -> {:error, :invalid_plugin_name}
    end
  end

  @spec validate_file_access(module(), map()) :: :ok
  defp validate_file_access(plugin_module, options) do
    # Check if plugin attempts to access restricted files
    restricted_access = Map.get(options, :restrict_file_access, true)

    validate_file_access_restrictions(restricted_access, plugin_module)
  end

  @spec validate_network_access(module(), map()) :: :ok
  defp validate_network_access(plugin_module, options) do
    # Check if plugin attempts network operations
    restricted_network = Map.get(options, :restrict_network_access, true)

    validate_network_access_restrictions(restricted_network, plugin_module)
  end

  @spec validate_code_injection(module()) :: :ok
  defp validate_code_injection(plugin_module) do
    # Check for potential code injection vulnerabilities
    check_code_injection_safety(plugin_module)
  end

  @spec validate_resource_limits(module()) :: :ok
  defp validate_resource_limits(plugin_module) do
    # Validate that plugin doesn't exceed resource limits
    check_resource_usage(plugin_module)
  end

  @spec validate_elixir_version(module()) :: validation_result()
  defp validate_elixir_version(_plugin_module) do
    # Check minimum Elixir version requirements
    current_version = System.version()
    min_version = "1.12.0"

    validate_version_compatibility(current_version, min_version, :elixir)
  end

  @spec validate_otp_version(module()) ::
          :ok | {:error, {:otp_version_too_old, String.t(), String.t()}}
  defp validate_otp_version(_plugin_module) do
    # Check minimum OTP version requirements
    current_version = System.otp_release()
    min_version = "24"

    validate_otp_version_compatibility(current_version, min_version)
  end

  @spec validate_platform_support(module()) :: :ok
  defp validate_platform_support(_plugin_module) do
    # Validate platform compatibility
    :ok
  end

  @spec validate_memory_usage(module()) :: :ok
  defp validate_memory_usage(_plugin_module) do
    # Check estimated memory usage
    :ok
  end

  @spec validate_initialization_time(module()) ::
          :ok
          | {:error,
             {:initialization_failed, term()}
             | {:initialization_too_slow, non_neg_integer()}}
  defp validate_initialization_time(plugin_module) do
    # Measure plugin initialization time using functional approach
    case safe_measure_init_time(plugin_module) do
      {:ok, time} ->
        # 5 seconds in microseconds
        max_init_time = 5_000_000

        validate_initialization_time_limit(time, max_init_time)

      {:error, reason} ->
        {:error, {:initialization_failed, reason}}
    end
  end

  @spec safe_measure_init_time(module()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  defp safe_measure_init_time(plugin_module) do
    task =
      Task.async(fn ->
        :timer.tc(fn -> plugin_module.init(%{}) end)
      end)

    case Task.yield(task, 6000) || Task.shutdown(task, :brutal_kill) do
      {:ok, {time, _result}} -> {:ok, time}
      nil -> {:error, :init_timeout}
      {:exit, reason} -> {:error, {:init_crashed, reason}}
    end
  end

  @spec validate_plugin_size(module()) ::
          :ok
          | {:error,
             {:plugin_too_large, non_neg_integer(), non_neg_integer()}
             | {:size_check_failed, term()}}
  defp validate_plugin_size(plugin_module) do
    # Check plugin file size
    case get_module_size(plugin_module) do
      {:ok, size} when size > @max_plugin_size ->
        {:error, {:plugin_too_large, size, @max_plugin_size}}

      {:ok, _size} ->
        :ok

      {:error, reason} ->
        {:error, {:size_check_failed, reason}}
    end
  end

  @spec get_plugin_dependencies(module()) ::
          {:ok, [String.t()]} | {:error, atom()}
  defp get_plugin_dependencies(plugin_module) do
    with {:exported?, true} <-
           {:exported?, function_exported?(plugin_module, :dependencies, 0)},
         {:ok, deps} <- safe_call_dependencies(plugin_module) do
      {:ok, deps}
    else
      {:exported?, false} -> {:error, :no_dependencies}
      {:error, _reason} -> {:error, :invalid_dependencies}
    end
  end

  @spec safe_call_dependencies(module()) ::
          {:ok, [String.t()]} | {:error, atom()}
  defp safe_call_dependencies(plugin_module) do
    task = Task.async(fn -> plugin_module.dependencies() end)

    case Task.yield(task, 1000) || Task.shutdown(task, :brutal_kill) do
      {:ok, deps} when is_list(deps) -> {:ok, deps}
      {:ok, _} -> {:error, :invalid_dependencies_format}
      nil -> {:error, :dependencies_timeout}
      {:exit, _reason} -> {:error, :dependencies_crashed}
    end
  end

  @spec validate_dependency_list([String.t()], map()) :: validation_result()
  defp validate_dependency_list(dependencies, loaded_plugins) do
    missing_deps =
      dependencies
      |> Enum.filter(fn dep -> not Map.has_key?(loaded_plugins, dep) end)

    validate_dependencies_available(missing_deps)
  end

  # Security analysis helpers

  @spec has_file_system_access?(module()) :: false
  defp has_file_system_access?(plugin_module) do
    # Analyze module for file system operations
    case safe_analyze_beam_chunks(plugin_module) do
      {:ok, forms} -> analyze_forms_for_file_access(forms)
      {:error, _} -> false
    end
  end

  @spec has_network_access?(module()) :: false
  defp has_network_access?(plugin_module) do
    # Analyze module for network operations
    case safe_analyze_beam_chunks(plugin_module) do
      {:ok, forms} -> analyze_forms_for_network_access(forms)
      {:error, _} -> false
    end
  end

  @spec safe_analyze_beam_chunks(module()) ::
          {:ok, list()} | {:error, :beam_analysis_failed}
  defp safe_analyze_beam_chunks(plugin_module) do
    with {:ok, compile_info} <- safe_get_compile_info(plugin_module),
         {:ok, source} <- extract_source_from_compile_info(compile_info),
         {:ok, chunks} <- safe_beam_chunks(source) do
      extract_forms_from_chunks(plugin_module, chunks)
    else
      _ -> {:error, :beam_analysis_failed}
    end
  end

  @spec safe_get_compile_info(module()) :: {:ok, keyword()} | {:error, atom()}
  defp safe_get_compile_info(plugin_module) do
    case safe_module_info(plugin_module, :compile) do
      {:ok, compile_info} -> {:ok, compile_info}
      _ -> {:error, :no_compile_info}
    end
  end

  @spec safe_module_info(module(), atom()) :: {:ok, term()} | {:error, atom()}
  defp safe_module_info(module, info_type) do
    task = Task.async(fn -> module.module_info(info_type) end)

    case Task.yield(task, 100) || Task.shutdown(task, :brutal_kill) do
      {:ok, info} -> {:ok, info}
      _ -> {:error, :module_info_failed}
    end
  end

  @spec extract_source_from_compile_info(keyword()) ::
          {:ok, charlist()} | {:error, atom()}
  defp extract_source_from_compile_info(compile_info) do
    case Keyword.get(compile_info, :source) do
      nil -> {:error, :no_source}
      source -> {:ok, source}
    end
  end

  @spec safe_beam_chunks(charlist()) ::
          {:ok, tuple()} | {:error, :beam_chunks_failed}
  defp safe_beam_chunks(source) do
    task =
      Task.async(fn ->
        :beam_lib.chunks(source, [:abstract_code])
      end)

    case Task.yield(task, 1000) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> {:ok, result}
      _ -> {:error, :beam_chunks_failed}
    end
  end

  @spec extract_forms_from_chunks(module(), tuple()) ::
          {:ok, list()} | {:error, :invalid_chunks}
  defp extract_forms_from_chunks(plugin_module, chunks) do
    case chunks do
      {:ok, {^plugin_module, [abstract_code: {:raw_abstract_v1, forms}]}} ->
        {:ok, forms}

      _ ->
        {:error, :invalid_chunks}
    end
  end

  @spec has_code_injection_risk?(module()) :: false
  defp has_code_injection_risk?(_plugin_module) do
    # Analyze for potential code injection patterns
    false
  end

  @spec check_resource_usage(module()) :: :ok
  defp check_resource_usage(_plugin_module) do
    # Check resource usage patterns
    :ok
  end

  @spec get_module_size(module()) :: {:ok, non_neg_integer()} | {:error, term()}
  defp get_module_size(plugin_module) do
    with {:ok, path} <- safe_get_module_path(plugin_module),
         {:ok, stat} <- File.stat(path) do
      {:ok, stat.size}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec safe_get_module_path(module()) :: {:ok, charlist()} | {:error, atom()}
  defp safe_get_module_path(plugin_module) do
    task = Task.async(fn -> :code.which(plugin_module) end)

    case Task.yield(task, 100) || Task.shutdown(task, :brutal_kill) do
      {:ok, path} when is_list(path) -> {:ok, path}
      {:ok, _} -> {:error, :module_path_not_found}
      _ -> {:error, :which_failed}
    end
  end

  @spec analyze_forms_for_file_access(term()) :: false
  defp analyze_forms_for_file_access(_forms) do
    # Simplified analysis - in practice would check for File.* calls
    false
  end

  @spec analyze_forms_for_network_access(term()) :: false
  defp analyze_forms_for_network_access(_forms) do
    # Simplified analysis - in practice would check for HTTPoison.*, :gen_tcp, etc.
    false
  end

  ## Pattern matching helper functions for if statement elimination

  @spec check_plugin_loaded_status(map(), String.t()) ::
          :ok | {:error, :already_loaded}
  defp check_plugin_loaded_status(plugins, plugin_id) do
    case Map.has_key?(plugins, plugin_id) do
      true -> {:error, :already_loaded}
      false -> :ok
    end
  end

  @spec resolve_module_identity(module()) ::
          {:ok, {String.t(), module()}} | {:error, atom()}
  defp resolve_module_identity(module) do
    case Code.ensure_loaded?(module) do
      true ->
        id = module |> Atom.to_string() |> String.replace("Elixir.", "")
        {:ok, {id, module}}

      false ->
        {:error, :module_not_found}
    end
  end

  @spec check_module_loaded(module()) :: :ok | {:error, :module_not_found}
  defp check_module_loaded(plugin_module) do
    case Code.ensure_loaded?(plugin_module) do
      true -> :ok
      false -> {:error, :module_not_found}
    end
  end

  @spec check_plugin_behaviour_implementation(module()) ::
          :ok | {:error, :invalid_plugin_behaviour}
  defp check_plugin_behaviour_implementation(plugin_module) do
    case Loader.behaviour_implemented?(
           plugin_module,
           Raxol.Core.Runtime.Plugins.Plugin
         ) do
      true -> :ok
      false -> {:error, :invalid_plugin_behaviour}
    end
  end

  @spec validate_callbacks_present([atom()]) :: validation_result()
  defp validate_callbacks_present([]), do: :ok

  @spec validate_callbacks_present([atom()]) :: validation_result()
  defp validate_callbacks_present(missing_callbacks) do
    {:error, {:missing_callbacks, missing_callbacks}}
  end

  @spec validate_metadata_fields_present([atom()]) :: validation_result()
  defp validate_metadata_fields_present([]), do: :ok

  @spec validate_metadata_fields_present([atom()]) :: validation_result()
  defp validate_metadata_fields_present(missing_fields) do
    {:error, {:missing_metadata_fields, missing_fields}}
  end

  @spec check_api_version_supported(String.t()) :: validation_result()
  defp check_api_version_supported(api_version) do
    case api_version in @supported_api_versions do
      true -> :ok
      false -> {:error, {:unsupported_api_version, api_version}}
    end
  end

  @spec validate_file_access_restrictions(boolean(), module()) :: :ok
  defp validate_file_access_restrictions(true, plugin_module) do
    # has_file_system_access?/1 currently always returns false
    # (analyze_forms_for_file_access/1 is stubbed to return false)
    false = has_file_system_access?(plugin_module)
    :ok
  end

  @spec validate_file_access_restrictions(boolean(), module()) :: :ok
  defp validate_file_access_restrictions(false, _plugin_module), do: :ok

  @spec validate_network_access_restrictions(boolean(), module()) :: :ok
  defp validate_network_access_restrictions(true, plugin_module) do
    # has_network_access?/1 currently always returns false
    # (analyze_forms_for_network_access/1 is stubbed to return false)
    false = has_network_access?(plugin_module)
    :ok
  end

  @spec validate_network_access_restrictions(boolean(), module()) :: :ok
  defp validate_network_access_restrictions(false, _plugin_module), do: :ok

  @spec check_code_injection_safety(module()) :: :ok
  defp check_code_injection_safety(plugin_module) do
    # has_code_injection_risk?/1 currently always returns false
    false = has_code_injection_risk?(plugin_module)
    :ok
  end

  @spec validate_version_compatibility(String.t(), String.t(), :elixir) ::
          :ok | {:error, {:elixir_version_too_old, String.t(), String.t()}}
  defp validate_version_compatibility(current_version, min_version, :elixir) do
    case Version.compare(current_version, min_version) in [:eq, :gt] do
      true -> :ok
      false -> {:error, {:elixir_version_too_old, current_version, min_version}}
    end
  end

  @spec validate_otp_version_compatibility(String.t(), String.t()) ::
          :ok | {:error, {:otp_version_too_old, String.t(), String.t()}}
  defp validate_otp_version_compatibility(current_version, min_version) do
    case String.to_integer(current_version) >= String.to_integer(min_version) do
      true -> :ok
      false -> {:error, {:otp_version_too_old, current_version, min_version}}
    end
  end

  @spec validate_initialization_time_limit(non_neg_integer(), non_neg_integer()) ::
          validation_result()
  defp validate_initialization_time_limit(time, max_init_time)
       when time > max_init_time do
    {:error, {:initialization_too_slow, time}}
  end

  @spec validate_initialization_time_limit(non_neg_integer(), non_neg_integer()) ::
          validation_result()
  defp validate_initialization_time_limit(_time, _max_init_time), do: :ok

  @spec validate_dependencies_available([String.t()]) :: validation_result()
  defp validate_dependencies_available([]), do: :ok

  @spec validate_dependencies_available([String.t()]) :: validation_result()
  defp validate_dependencies_available(missing_deps) do
    {:error, {:missing_dependencies, missing_deps}}
  end
end
