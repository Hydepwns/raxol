defmodule Mix.Tasks.Raxol.PreCommit do
  @moduledoc """
  Run all pre-commit checks for the Raxol project.

  ## Usage

      mix raxol.pre_commit [options]
      
  ## Options

    * `--parallel` - Run checks in parallel (default: true)
    * `--fail-fast` - Stop on first failure (default: false)
    * `--only` - Run only specific checks (comma-separated)
    * `--skip` - Skip specific checks (comma-separated)
    * `--quiet` - Minimal output
    * `--verbose` - Detailed output with timing
    * `--fix` - Auto-fix issues when possible (currently: format)
    
  ## Examples

      # Run all checks
      mix raxol.pre_commit
      
      # Run with auto-fix
      mix raxol.pre_commit --fix
      
      # Run only format and compile checks
      mix raxol.pre_commit --only format,compile
      
      # Skip docs check
      mix raxol.pre_commit --skip docs
      
      # Sequential execution with fail-fast
      mix raxol.pre_commit --no-parallel --fail-fast
  """

  use Mix.Task

  @shortdoc "Run all pre-commit checks"

  @default_checks [:format, :compile, :credo, :tests, :docs]
  @check_modules %{
    format: Mix.Tasks.Raxol.Check.Format,
    compile: Mix.Tasks.Raxol.Check.Compile,
    credo: Mix.Tasks.Raxol.Check.Credo,
    tests: Mix.Tasks.Raxol.Check.Tests,
    docs: Mix.Tasks.Raxol.Check.Docs
  }

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          parallel: :boolean,
          fail_fast: :boolean,
          only: :string,
          skip: :string,
          quiet: :boolean,
          verbose: :boolean,
          fix: :boolean
        ],
        aliases: [
          p: :parallel,
          f: :fail_fast,
          q: :quiet,
          v: :verbose
        ]
      )

    config = build_config(opts)

    unless config.quiet do
      IO.puts("\n🚀 Running Raxol Pre-commit Checks\n")
    end

    start_time = System.monotonic_time(:millisecond)

    checks = determine_checks(config)
    results = run_checks(checks, config)

    elapsed = System.monotonic_time(:millisecond) - start_time

    print_summary(results, elapsed, config)

    exit_code = if all_passed?(results), do: 0, else: 1
    System.halt(exit_code)
  end

  defp build_config(opts) do
    %{
      parallel: Keyword.get(opts, :parallel, true),
      fail_fast: Keyword.get(opts, :fail_fast, false),
      only: parse_check_list(Keyword.get(opts, :only)),
      skip: parse_check_list(Keyword.get(opts, :skip)),
      quiet: Keyword.get(opts, :quiet, false),
      verbose: Keyword.get(opts, :verbose, false),
      auto_fix: Keyword.get(opts, :fix, false)
    }
  end

  defp parse_check_list(nil), do: []

  defp parse_check_list(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)
  end

  defp determine_checks(config) do
    checks =
      if config.only != [] do
        config.only
      else
        @default_checks
      end

    checks
    |> Enum.reject(&(&1 in config.skip))
    |> Enum.map(&{&1, Map.get(@check_modules, &1)})
    |> Enum.filter(fn {_, module} -> module != nil end)
  end

  defp run_checks(checks, %{parallel: true, fail_fast: false} = config) do
    checks
    |> Task.async_stream(
      fn {name, module} ->
        {name, run_single_check(module, config)}
      end,
      ordered: true,
      timeout: 30_000
    )
    |> Enum.map(fn {:ok, result} -> result end)
  end

  defp run_checks(checks, %{parallel: false} = config) do
    Enum.reduce_while(checks, [], fn {name, module}, acc ->
      result = run_single_check(module, config)
      new_acc = [{name, result} | acc]

      if config.fail_fast and result.status == :error do
        {:halt, Enum.reverse(new_acc)}
      else
        {:cont, new_acc}
      end
    end)
    |> Enum.reverse()
  end

  defp run_checks(checks, config) do
    # Parallel with fail-fast (more complex, simplified for now)
    run_checks(checks, %{config | parallel: false})
  end

  defp run_single_check(module, config) do
    start_time = System.monotonic_time(:millisecond)

    result =
      try do
        # Ensure module is compiled and loaded
        case Code.ensure_compiled(module) do
          {:module, _} ->
            if function_exported?(module, :run, 1) do
              module.run(config)
            else
              {:error, "Check module #{inspect(module)} not implemented"}
            end

          {:error, _} ->
            # Try loading all Mix tasks
            Mix.Task.load_all()
            # Retry
            case Code.ensure_compiled(module) do
              {:module, _} ->
                if function_exported?(module, :run, 1) do
                  module.run(config)
                else
                  {:error, "Check module #{inspect(module)} not implemented"}
                end

              {:error, reason} ->
                {:error,
                 "Module #{inspect(module)} not found: #{inspect(reason)}"}
            end
        end
      rescue
        e -> {:error, Exception.format(:error, e, __STACKTRACE__)}
      catch
        :exit, reason -> {:error, "Check exited: #{inspect(reason)}"}
      end

    elapsed = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, details} ->
        %{status: :ok, details: details, elapsed: elapsed}

      {:error, reason} ->
        %{status: :error, reason: reason, elapsed: elapsed}

      {:warning, reason} ->
        %{status: :warning, reason: reason, elapsed: elapsed}
    end
  end

  defp all_passed?(results) do
    Enum.all?(results, fn {_, result} ->
      result.status in [:ok, :warning]
    end)
  end

  defp print_summary(results, total_elapsed, config) do
    unless config.quiet do
      IO.puts("\n" <> String.duplicate("─", 50))
      IO.puts("📊 Pre-commit Check Summary\n")

      Enum.each(results, fn {name, result} ->
        icon =
          case result.status do
            :ok -> "✅"
            :warning -> "⚠️ "
            :error -> "❌"
          end

        time_str =
          if config.verbose do
            " (#{result.elapsed}ms)"
          else
            ""
          end

        check_name = name |> to_string() |> String.capitalize()
        IO.puts("  #{icon} #{check_name}#{time_str}")

        if result.status == :error and result[:reason] do
          IO.puts("     #{result.reason}")
        end
      end)

      IO.puts("\n" <> String.duplicate("─", 50))

      passed = Enum.count(results, fn {_, r} -> r.status == :ok end)
      warnings = Enum.count(results, fn {_, r} -> r.status == :warning end)
      failed = Enum.count(results, fn {_, r} -> r.status == :error end)
      total = length(results)

      IO.puts(
        "Total: #{total} checks, #{passed} passed, #{warnings} warnings, #{failed} failed"
      )

      IO.puts("Time: #{format_time(total_elapsed)}\n")

      if all_passed?(results) do
        IO.puts("✨ All checks passed! Ready to commit.")
      else
        IO.puts("❌ Pre-commit checks failed. Please fix the issues above.")
      end
    end
  end

  defp format_time(ms) when ms < 1000, do: "#{ms}ms"
  defp format_time(ms), do: "#{Float.round(ms / 1000, 1)}s"
end
