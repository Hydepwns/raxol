defmodule Raxol.Core.Runtime.Plugins.Security.BeamAnalyzer do
  @moduledoc """
  BEAM bytecode analyzer for detecting security-sensitive operations.

  This module analyzes the abstract syntax tree (AST) of compiled BEAM modules
  to detect potentially dangerous operations such as:

  - File system access
  - Network access
  - Code injection / dynamic evaluation
  - System command execution
  - Process spawning with external commands

  ## Usage

      {:ok, capabilities} = BeamAnalyzer.analyze_module(MyPlugin)
      # => {:ok, %{file_access: true, network_access: false, code_injection: false}}

  """

  @type capability :: :file_access | :network_access | :code_injection | :system_commands
  @type capabilities :: %{capability() => boolean()}
  @type analysis_result :: {:ok, capabilities()} | {:error, term()}

  # Modules/functions that indicate file system access
  @file_access_patterns [
    # Elixir File module
    {File, :read},
    {File, :write},
    {File, :read!},
    {File, :write!},
    {File, :rm},
    {File, :rm!},
    {File, :rm_rf},
    {File, :rm_rf!},
    {File, :mkdir},
    {File, :mkdir!},
    {File, :mkdir_p},
    {File, :mkdir_p!},
    {File, :cp},
    {File, :cp!},
    {File, :cp_r},
    {File, :cp_r!},
    {File, :rename},
    {File, :rename!},
    {File, :open},
    {File, :open!},
    {File, :stream!},
    {File, :ls},
    {File, :ls!},
    {File, :stat},
    {File, :stat!},
    {File, :lstat},
    {File, :lstat!},
    {File, :exists?},
    {File, :regular?},
    {File, :dir?},
    # Erlang file module
    {:file, :open},
    {:file, :read},
    {:file, :write},
    {:file, :read_file},
    {:file, :write_file},
    {:file, :delete},
    {:file, :rename},
    {:file, :make_dir},
    {:file, :del_dir},
    {:file, :list_dir},
    {:file, :read_file_info},
    {:file, :write_file_info},
    {:file, :consult},
    {:file, :eval},
    # IO module file operations
    {IO, :binread},
    {IO, :binwrite},
    # Path module (indicates file path manipulation)
    {Path, :join},
    {Path, :expand},
    {Path, :absname}
  ]

  # Modules/functions that indicate network access
  @network_access_patterns [
    # Erlang networking
    {:gen_tcp, :connect},
    {:gen_tcp, :listen},
    {:gen_tcp, :accept},
    {:gen_tcp, :send},
    {:gen_tcp, :recv},
    {:gen_udp, :open},
    {:gen_udp, :send},
    {:gen_udp, :recv},
    {:ssl, :connect},
    {:ssl, :listen},
    {:ssl, :send},
    {:ssl, :recv},
    {:inet, :getaddr},
    {:inet, :gethostbyname},
    {:httpc, :request},
    {:httpc, :set_options},
    # Common HTTP libraries
    {HTTPoison, :get},
    {HTTPoison, :get!},
    {HTTPoison, :post},
    {HTTPoison, :post!},
    {HTTPoison, :put},
    {HTTPoison, :put!},
    {HTTPoison, :delete},
    {HTTPoison, :delete!},
    {HTTPoison, :request},
    {HTTPoison, :request!},
    {Req, :get},
    {Req, :get!},
    {Req, :post},
    {Req, :post!},
    {Req, :put},
    {Req, :put!},
    {Req, :delete},
    {Req, :delete!},
    {Req, :request},
    {Req, :request!},
    {Req, :new},
    {Tesla, :get},
    {Tesla, :post},
    {Tesla, :put},
    {Tesla, :delete},
    {Tesla, :request},
    {Finch, :build},
    {Finch, :request},
    # WebSocket
    {:websocket_client, :start_link},
    {WebSockex, :start_link},
    {WebSockex, :send_frame}
  ]

  # Modules/functions that indicate code injection risk
  @code_injection_patterns [
    # Dynamic code evaluation
    {Code, :eval_string},
    {Code, :eval_file},
    {Code, :eval_quoted},
    {Code, :compile_string},
    {Code, :compile_file},
    {Code, :compile_quoted},
    {:erl_eval, :expr},
    {:erl_eval, :exprs},
    {:erl_eval, :expr_list},
    # Dynamic module compilation
    {Module, :create},
    {:code, :load_binary},
    {:code, :load_file},
    {:code, :load_abs},
    # Dynamic function application with string/atom conversion
    {:erlang, :apply},
    {Kernel, :apply},
    # Macro expansion at runtime
    {Macro, :expand},
    {Macro, :expand_once}
  ]

  # System command execution patterns
  @system_command_patterns [
    # System commands
    {System, :cmd},
    {System, :shell},
    # Ports (external program interaction)
    {Port, :open},
    {:erlang, :open_port},
    # OS commands
    {:os, :cmd}
  ]

  @doc """
  Analyzes a module's BEAM bytecode to detect security-sensitive operations.

  Returns a map of capability flags indicating what the module can do.
  """
  @spec analyze_module(module()) :: analysis_result()
  def analyze_module(module) when is_atom(module) do
    with {:ok, forms} <- get_abstract_code(module) do
      capabilities = analyze_forms(forms)
      {:ok, capabilities}
    end
  end

  @doc """
  Checks if a module has file system access capabilities.
  """
  @spec has_file_access?(module()) :: boolean()
  def has_file_access?(module) do
    case analyze_module(module) do
      {:ok, %{file_access: true}} -> true
      _ -> false
    end
  end

  @doc """
  Checks if a module has network access capabilities.
  """
  @spec has_network_access?(module()) :: boolean()
  def has_network_access?(module) do
    case analyze_module(module) do
      {:ok, %{network_access: true}} -> true
      _ -> false
    end
  end

  @doc """
  Checks if a module has code injection capabilities.
  """
  @spec has_code_injection_risk?(module()) :: boolean()
  def has_code_injection_risk?(module) do
    case analyze_module(module) do
      {:ok, %{code_injection: true}} -> true
      _ -> false
    end
  end

  @doc """
  Checks if a module has system command execution capabilities.
  """
  @spec has_system_command_access?(module()) :: boolean()
  def has_system_command_access?(module) do
    case analyze_module(module) do
      {:ok, %{system_commands: true}} -> true
      _ -> false
    end
  end

  # --- Private Implementation ---

  defp get_abstract_code(module) do
    # First try to get debug_info from the loaded module
    case get_chunks_from_loaded_module(module) do
      {:ok, forms} ->
        {:ok, forms}

      :error ->
        # Fall back to reading from beam file
        get_chunks_from_beam_file(module)
    end
  end

  defp get_chunks_from_loaded_module(module) do
    case :code.which(module) do
      :preloaded ->
        :error

      :non_existing ->
        :error

      path when is_list(path) ->
        get_chunks_from_beam_file(path)
    end
  end

  defp get_chunks_from_beam_file(path_or_module) do
    path =
      case path_or_module do
        p when is_list(p) -> p
        mod when is_atom(mod) -> :code.which(mod)
      end

    case :beam_lib.chunks(path, [:abstract_code]) do
      {:ok, {_module, [{:abstract_code, {:raw_abstract_v1, forms}}]}} ->
        {:ok, forms}

      {:ok, {_module, [{:abstract_code, :no_abstract_code}]}} ->
        # Module compiled without debug_info
        {:error, :no_abstract_code}

      {:error, :beam_lib, reason} ->
        {:error, {:beam_lib_error, reason}}

      _ ->
        {:error, :unknown_beam_format}
    end
  end

  defp analyze_forms(forms) do
    # Walk the AST and collect all remote calls
    remote_calls = extract_remote_calls(forms)

    %{
      file_access: has_pattern_match?(remote_calls, @file_access_patterns),
      network_access: has_pattern_match?(remote_calls, @network_access_patterns),
      code_injection: has_pattern_match?(remote_calls, @code_injection_patterns),
      system_commands: has_pattern_match?(remote_calls, @system_command_patterns)
    }
  end

  defp extract_remote_calls(forms) do
    forms
    |> Enum.flat_map(&extract_calls_from_form/1)
    |> Enum.uniq()
  end

  defp extract_calls_from_form(form) do
    walk_form(form, [])
  end

  # Walk the Erlang abstract format and extract remote calls
  # The format is based on Erlang abstract code format (erl_parse)

  defp walk_form(form, acc) when is_tuple(form) do
    case form do
      # Remote call: Module:Function(Args)
      {:call, _line, {:remote, _line2, module_ast, function_ast}, args} ->
        calls = extract_module_function(module_ast, function_ast)
        new_acc = calls ++ acc
        # Also walk the arguments
        Enum.reduce(args, new_acc, &walk_form/2)

      # Local call (might be delegated)
      {:call, _line, {:atom, _line2, _function}, args} ->
        Enum.reduce(args, acc, &walk_form/2)

      # Walk all tuple elements
      _ ->
        form
        |> Tuple.to_list()
        |> Enum.reduce(acc, &walk_form/2)
    end
  end

  defp walk_form(form, acc) when is_list(form) do
    Enum.reduce(form, acc, &walk_form/2)
  end

  defp walk_form(_form, acc), do: acc

  defp extract_module_function(module_ast, function_ast) do
    module = extract_atom(module_ast)
    function = extract_atom(function_ast)

    case {module, function} do
      {nil, _} -> []
      {_, nil} -> []
      {mod, fun} -> [{mod, fun}]
    end
  end

  defp extract_atom({:atom, _line, atom}) when is_atom(atom), do: atom
  defp extract_atom(_), do: nil

  defp has_pattern_match?(remote_calls, patterns) do
    Enum.any?(remote_calls, fn {module, function} ->
      Enum.any?(patterns, fn {pattern_module, pattern_function} ->
        module_matches?(module, pattern_module) and function == pattern_function
      end)
    end)
  end

  defp module_matches?(actual_module, pattern_module) do
    # Handle both Elixir and Erlang modules
    case {actual_module, pattern_module} do
      {same, same} ->
        true

      # Handle Elixir module naming (e.g., Elixir.File vs File)
      {actual, expected} when is_atom(actual) and is_atom(expected) ->
        actual_str = Atom.to_string(actual)
        expected_str = Atom.to_string(expected)

        # Check if actual is the full Elixir module name
        String.ends_with?(actual_str, "." <> expected_str) or
          actual_str == "Elixir." <> expected_str or
          actual_str == expected_str

      _ ->
        false
    end
  end
end
