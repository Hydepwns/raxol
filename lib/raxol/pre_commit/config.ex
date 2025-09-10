defmodule Raxol.PreCommit.Config do
  @moduledoc """
  Configuration system for Raxol pre-commit checks.

  Loads and merges configuration from multiple sources:
  1. Default configuration
  2. Project-level .raxol.exs file
  3. Command-line options (highest priority)

  ## Configuration File Format

  Create a `.raxol.exs` file in your project root:

  ```elixir
  [
    pre_commit: [
      checks: [:format, :compile, :credo, :tests],
      parallel: true,
      fail_fast: false,
      auto_fix: [:format],
      test_timeout: 5_000,
      ignore_paths: ["deps/", "_build/", "priv/static/"],
      custom_checks: [],
      check_config: [
        format: [
          inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
        ],
        tests: [
          timeout: 10_000,
          max_failures: 10
        ],
        credo: [
          strict: true,
          all: false
        ]
      ]
    ]
  ]
  ```
  """

  @config_file ".raxol.exs"

  @default_config %{
    checks: [:format, :compile, :credo, :tests, :docs],
    parallel: true,
    fail_fast: false,
    auto_fix: false,
    quiet: false,
    verbose: false,
    no_cache: false,
    test_timeout: 5_000,
    ignore_paths: ["deps/", "_build/"],
    custom_checks: [],
    check_config: %{}
  }

  @doc """
  Load configuration from all sources and merge them.

  Priority (highest to lowest):
  1. Command-line options
  2. .raxol.exs file
  3. Default configuration
  """
  def load(cli_opts \\ %{}) do
    @default_config
    |> merge_file_config()
    |> merge_cli_config(cli_opts)
    |> validate_config()
  end

  @doc """
  Get configuration for a specific check.
  """
  def get_check_config(config, check_name) do
    check_config = Map.get(config.check_config, check_name, %{})

    # Merge check-specific config with global config
    Map.merge(config, check_config)
  end

  @doc """
  Check if a path should be ignored based on configuration.
  """
  def should_ignore?(config, path) do
    Enum.any?(config.ignore_paths, &String.starts_with?(path, &1))
  end

  # Private functions

  defp merge_file_config(config) do
    case load_config_file() do
      {:ok, file_config} ->
        deep_merge(config, file_config)

      :not_found ->
        config

      {:error, reason} ->
        IO.warn("Failed to load .raxol.exs: #{inspect(reason)}")
        config
    end
  end

  defp load_config_file do
    config_path = Path.expand(@config_file)

    case File.exists?(config_path) do
      true ->
        try do
          {result, _bindings} = Code.eval_file(config_path)

          pre_commit_config =
            result
            |> Keyword.get(:pre_commit, [])
            |> keyword_to_map()

          {:ok, pre_commit_config}
        rescue
          e ->
            {:error, Exception.format(:error, e, __STACKTRACE__)}
        end

      false ->
        :not_found
    end
  end

  defp keyword_to_map(keyword) when is_list(keyword) do
    Enum.into(keyword, %{}, fn
      {key, value} when is_list(value) ->
        # Check if it's a keyword list
        case Keyword.keyword?(value) do
          true -> {key, keyword_to_map(value)}
          false -> {key, value}
        end

      {key, value} ->
        {key, value}
    end)
  end

  defp keyword_to_map(value), do: value

  defp merge_cli_config(config, cli_opts) do
    # CLI options override file config
    Map.merge(config, cli_opts, fn _key, _file_val, cli_val -> cli_val end)
  end

  defp validate_config(config) do
    config
    |> validate_checks()
    |> validate_timeouts()
    |> validate_paths()
  end

  defp validate_checks(%{checks: checks} = config) when is_list(checks) do
    valid_checks =
      MapSet.new([
        :format,
        :compile,
        :credo,
        :tests,
        :docs,
        :dialyzer,
        :security,
        :unused,
        :metrics
      ])

    invalid = Enum.reject(checks, &MapSet.member?(valid_checks, &1))

    case invalid do
      [] ->
        config

      invalid_checks ->
        IO.warn("Unknown checks in configuration: #{inspect(invalid_checks)}")

        %{
          config
          | checks: Enum.filter(checks, &MapSet.member?(valid_checks, &1))
        }
    end
  end

  defp validate_checks(config), do: config

  defp validate_timeouts(%{test_timeout: timeout} = config)
       when is_integer(timeout) and timeout > 0 do
    config
  end

  defp validate_timeouts(%{test_timeout: _} = config) do
    IO.warn("Invalid test_timeout, using default: 5000ms")
    %{config | test_timeout: 5_000}
  end

  defp validate_timeouts(config), do: config

  defp validate_paths(%{ignore_paths: paths} = config) when is_list(paths) do
    # Ensure paths end with / for directory matching
    normalized_paths =
      Enum.map(paths, fn path ->
        case String.ends_with?(path, "/") do
          true ->
            path

          false ->
            case File.dir?(path) do
              true -> path <> "/"
              false -> path
            end
        end
      end)

    %{config | ignore_paths: normalized_paths}
  end

  defp validate_paths(config), do: config

  defp deep_merge(map1, map2) when is_map(map1) and is_map(map2) do
    Map.merge(map1, map2, fn
      _key, val1, val2 when is_map(val1) and is_map(val2) ->
        deep_merge(val1, val2)

      _key, _val1, val2 ->
        val2
    end)
  end

  defp deep_merge(_map1, map2), do: map2
end
