defmodule Mix.Tasks.Raxol.Config do
  @moduledoc """
  Configuration management for Raxol.

  ## Usage

      mix raxol.config [command] [options]

  ## Commands

    * `init` - Initialize a new configuration file
    * `validate` - Validate existing configuration
    * `generate` - Generate configuration templates
    * `docs` - Generate configuration documentation
    * `show` - Show current configuration
    * `get` - Get a specific configuration value
    * `set` - Set a configuration value
    * `backup` - Backup current configuration
    * `migrate` - Migrate configuration to new format

  ## Options

    * `--file` - Configuration file path (default: config/raxol.toml)
    * `--format` - Output format: toml, json, yaml (default: toml)
    * `--env` - Environment: development, production, test
    * `--minimal` - Generate minimal configuration
    * `--with-comments` - Include comments in generated config
    * `--with-examples` - Include examples in generated config
    * `--output` - Output file or directory

  ## Examples

      # Initialize a new configuration file
      mix raxol.config init

      # Initialize with specific format and options
      mix raxol.config init --format json --with-comments

      # Validate current configuration
      mix raxol.config validate

      # Generate template configuration
      mix raxol.config generate --output config/template.toml

      # Show current configuration
      mix raxol.config show

      # Get specific configuration value
      mix raxol.config get terminal.width

      # Set configuration value
      mix raxol.config set terminal.width 120

      # Generate documentation
      mix raxol.config docs --output docs/config.md

      # Generate environment-specific config
      mix raxol.config init --env production --output config/prod.toml
  """

  use Mix.Task

  alias Raxol.Config.{Generator, Loader, Schema}

  @shortdoc "Manage Raxol configuration"

  @impl Mix.Task
  def run(args) do
    {opts, args, _} =
      OptionParser.parse(args,
        switches: [
          file: :string,
          format: :string,
          env: :string,
          minimal: :boolean,
          with_comments: :boolean,
          with_examples: :boolean,
          output: :string,
          help: :boolean
        ],
        aliases: [
          f: :file,
          o: :output,
          h: :help
        ]
      )

    handle_help_request(opts[:help])

    command = List.first(args) || "help"

    Mix.Task.run("app.start")

    case command do
      "init" ->
        handle_init(opts)

      "validate" ->
        handle_validate(opts)

      "generate" ->
        handle_generate(opts)

      "docs" ->
        handle_docs(opts)

      "show" ->
        handle_show(opts)

      "get" ->
        handle_get(args, opts)

      "set" ->
        handle_set(args, opts)

      "backup" ->
        handle_backup(opts)

      "migrate" ->
        handle_migrate(opts)

      "help" ->
        Mix.shell().info(@moduledoc)

      _ ->
        Mix.shell().error("Unknown command: #{command}")
        Mix.shell().info("Run 'mix raxol.config help' for usage information")
    end
  end

  defp handle_help_request(true) do
    Mix.shell().info(@moduledoc)
    :ok
  end

  defp handle_help_request(_) do
    :ok
  end

  defp handle_init(opts) do
    file_path = get_config_path(opts)
    format = get_format(opts, file_path)
    env = String.to_atom(opts[:env] || "development")

    Mix.shell().info("Initializing Raxol configuration...")

    should_cancel = File.exists?(file_path) and not confirm_overwrite(file_path)
    handle_init_cancellation(should_cancel)

    result = generate_config(file_path, format, env, opts)
    handle_init_result(result)
  end

  defp handle_init_cancellation(true) do
    Mix.shell().info("Configuration initialization cancelled.")
    :ok
  end

  defp handle_init_cancellation(false) do
    :ok
  end

  defp generate_config(file_path, format, env, opts) do
    select_config_generation(opts[:minimal], file_path, format, env, opts)
  end

  defp select_config_generation(true, file_path, _format, _env, _opts) do
    Generator.generate_minimal_config(file_path)
  end

  defp select_config_generation(false, file_path, format, env, opts) do
    generate_env_or_default_config(file_path, format, env, opts)
  end

  defp select_config_generation(nil, file_path, format, env, opts) do
    generate_env_or_default_config(file_path, format, env, opts)
  end

  defp generate_env_or_default_config(file_path, format, env, opts) do
    case env do
      env when env in [:development, :production, :test] ->
        Generator.generate_env_config(env, file_path, opts)

      _ ->
        Generator.generate_default_config(file_path,
          format: format,
          comments: opts[:with_comments],
          examples: opts[:with_examples]
        )
    end
  end

  defp handle_init_result({:ok, path}) do
    Mix.shell().info("✅ Configuration initialized at #{path}")
    show_next_steps(path)
  end

  defp handle_init_result({:error, reason}) do
    Mix.shell().error(
      "❌ Failed to initialize configuration: #{inspect(reason)}"
    )
  end

  defp handle_validate(opts) do
    file_path = get_config_path(opts)

    Mix.shell().info("Validating configuration at #{file_path}...")

    case Loader.load_file(file_path) do
      {:ok, config} ->
        case Schema.validate_config(config) do
          {:ok, :valid} ->
            Mix.shell().info("✅ Configuration is valid")
            show_config_summary(config)

          {:error, errors} ->
            Mix.shell().error("❌ Configuration validation failed:")
            show_validation_errors(errors)
        end

      {:error, reason} ->
        Mix.shell().error("❌ Failed to load configuration: #{inspect(reason)}")
    end
  end

  defp handle_generate(opts) do
    output_path = opts[:output] || "config/template.toml"

    Mix.shell().info("Generating configuration template...")

    case Generator.generate_template(output_path, opts) do
      :ok ->
        Mix.shell().info("✅ Configuration template generated at #{output_path}")

      {:error, reason} ->
        Mix.shell().error("❌ Failed to generate template: #{inspect(reason)}")
    end
  end

  defp handle_docs(opts) do
    output_path = opts[:output] || "docs/configuration.md"

    Mix.shell().info("Generating configuration documentation...")

    result = Generator.generate_config_docs(output_path)
    handle_docs_result(result)
  end

  defp handle_docs_result({:ok, path}) do
    Mix.shell().info("✅ Configuration documentation generated at #{path}")
  end

  defp handle_show(opts) do
    file_path = get_config_path(opts)
    format = String.to_atom(opts[:format] || "pretty")

    Mix.shell().info("Current configuration from #{file_path}:")
    Mix.shell().info(String.duplicate("=", 50))

    result = Loader.load_file(file_path)
    handle_show_result(result, format)
  end

  defp handle_show_result({:ok, config}, format) do
    show_config(config, format)
  end

  defp handle_show_result({:error, reason}, _format) do
    Mix.shell().error("❌ Failed to load configuration: #{inspect(reason)}")

    Mix.shell().info(
      "💡 Run 'mix raxol.config init' to create a configuration file"
    )
  end

  defp handle_get([_, key | _], opts) do
    file_path = get_config_path(opts)

    case Loader.load_file(file_path) do
      {:ok, config} ->
        key_path = parse_key_path(key)
        value = get_nested_value(config, key_path)

        handle_config_value_display(value, key)

      {:error, reason} ->
        Mix.shell().error("❌ Failed to load configuration: #{inspect(reason)}")
    end
  end

  defp handle_get(_, _) do
    Mix.shell().error("Usage: mix raxol.config get <key>")
    Mix.shell().info("Example: mix raxol.config get terminal.width")
  end

  defp handle_config_value_display(nil, key) do
    Mix.shell().error("Configuration key not found: #{key}")
  end

  defp handle_config_value_display(value, key) do
    Mix.shell().info("#{key}: #{inspect(value)}")
  end

  defp handle_set([_, key, value | _], opts) do
    file_path = get_config_path(opts)

    Mix.shell().info("Setting #{key} = #{value} in #{file_path}")

    Mix.shell().info("❌ Config modification not yet implemented")
    Mix.shell().info("💡 Please edit the configuration file manually")
  end

  defp handle_set(_, _) do
    Mix.shell().error("Usage: mix raxol.config set <key> <value>")
    Mix.shell().info("Example: mix raxol.config set terminal.width 120")
  end

  defp handle_backup(opts) do
    file_path = get_config_path(opts)

    case Loader.backup_config(file_path) do
      {:ok, backup_path} ->
        Mix.shell().info("✅ Configuration backed up to #{backup_path}")

      {:error, :file_not_found} ->
        Mix.shell().error("❌ Configuration file not found: #{file_path}")

      {:error, reason} ->
        Mix.shell().error("❌ Backup failed: #{inspect(reason)}")
    end
  end

  defp handle_migrate(opts) do
    file_path = get_config_path(opts)

    Mix.shell().info("Configuration migration not yet implemented")
    Mix.shell().info("Current file: #{file_path}")
  end

  defp get_config_path(opts) do
    opts[:file] || "config/raxol.toml"
  end

  defp get_format(opts, file_path) do
    case opts[:format] do
      nil -> detect_format_from_path(file_path)
      format -> String.to_atom(format)
    end
  end

  defp detect_format_from_path(path) do
    case String.downcase(Path.extname(path)) do
      ".toml" -> :toml
      ".json" -> :json
      ".yaml" -> :yaml
      ".yml" -> :yaml
      _ -> :toml
    end
  end

  defp confirm_overwrite(path) do
    Mix.shell().yes?("Configuration file #{path} already exists. Overwrite?")
  end

  defp show_next_steps(path) do
    Mix.shell().info("""

    Next steps:
    1. Review and customize the configuration in #{path}
    2. Validate your configuration: mix raxol.config validate
    3. View current settings: mix raxol.config show
    """)
  end

  defp show_config_summary(config) do
    sections = Map.keys(config)
    total_options = count_config_options(config)

    Mix.shell().info("")
    Mix.shell().info("Configuration summary:")
    Mix.shell().info("  Sections: #{Enum.join(sections, ", ")}")
    Mix.shell().info("  Total options: #{total_options}")
  end

  defp count_config_options(config) when is_map(config) do
    Enum.reduce(config, 0, fn {_key, value}, acc ->
      count_single_config_option(is_map(value), value, acc)
    end)
  end

  defp count_single_config_option(true, value, acc) do
    acc + count_config_options(value)
  end

  defp count_single_config_option(false, _value, acc) do
    acc + 1
  end

  defp show_validation_errors(errors) do
    Enum.each(errors, fn {path, error} ->
      path_str = Enum.join(path, ".")
      Mix.shell().error("  • #{path_str}: #{error}")
    end)
  end

  defp show_config(config, :json) do
    case Jason.encode(config, pretty: true) do
      {:ok, json} -> Mix.shell().info(json)
      {:error, _} -> show_config(config, :pretty)
    end
  end

  defp show_config(config, :compact) do
    Mix.shell().info(inspect(config))
  end

  defp show_config(config, _) do
    show_config_section(config, [], 0)
  end

  defp show_config_section(config, path, indent) when is_map(config) do
    indent_str = String.duplicate("  ", indent)

    Enum.each(config, fn {key, value} ->
      current_path = path ++ [key]

      case value do
        v when is_map(v) ->
          Mix.shell().info("#{indent_str}#{key}:")
          show_config_section(v, current_path, indent + 1)

        v ->
          Mix.shell().info("#{indent_str}#{key}: #{inspect(v)}")
      end
    end)
  end

  defp parse_key_path(key) do
    key
    |> String.split(".")
    |> Enum.map(&String.to_atom/1)
  end

  defp get_nested_value(map, []), do: map

  defp get_nested_value(map, [key | rest]) when is_map(map) do
    case Map.get(map, key) do
      nil -> nil
      value -> get_nested_value(value, rest)
    end
  end

  defp get_nested_value(_, _), do: nil
end
