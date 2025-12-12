defmodule Mix.Tasks.Raxol.Check do
  @moduledoc """
  Run comprehensive quality checks on the Raxol codebase.

  This task runs multiple quality checks in sequence:
  1. Compilation check
  2. Format check
  3. Credo analysis
  4. Dialyzer (if available)
  5. Security audit
  6. Test suite

  ## Usage

      mix raxol.check [OPTIONS]

  ## Options

    * `--only CHECKS` - Run only specific checks (comma-separated)
    * `--skip CHECKS` - Skip specific checks (comma-separated)
    * `--strict` - Run all checks in strict mode
    * `--quick` - Run only fast checks (skip dialyzer)

  ## Examples

      # Run all checks
      mix raxol.check

      # Run only format and compile checks
      mix raxol.check --only compile,format

      # Skip dialyzer
      mix raxol.check --skip dialyzer

      # Quick check (no dialyzer)
      mix raxol.check --quick
  """

  use Mix.Task
  require Logger

  @shortdoc "Run comprehensive quality checks"

  @all_checks [:compile, :format, :credo, :dialyzer, :security, :test]
  @quick_checks [:compile, :format, :credo, :test]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          only: :string,
          skip: :string,
          strict: :boolean,
          quick: :boolean
        ]
      )

    checks = determine_checks(opts)

    Mix.shell().info("Running Raxol quality checks: #{inspect(checks)}")
    Mix.shell().info("")

    results = Enum.map(checks, &run_check/1)

    print_summary(results)

    # Only fail on actual errors, not warnings or skipped checks
    case Enum.any?(results, fn {_, status} -> status == :error end) do
      true -> Mix.raise("Some checks failed")
      false -> :ok
    end
  end

  defp determine_checks(opts) do
    base_checks =
      cond do
        opts[:only] ->
          parse_check_list(opts[:only])

        opts[:quick] ->
          @quick_checks

        true ->
          @all_checks
      end

    # Apply skip filter after determining base checks
    case opts[:skip] do
      nil ->
        base_checks

      skip_str ->
        skip = parse_check_list(skip_str)
        Enum.reject(base_checks, &(&1 in skip))
    end
  end

  defp parse_check_list(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)
  end

  defp run_check(:compile) do
    Mix.shell().info("==> Running compilation check...")

    try do
      System.put_env("TMPDIR", "/tmp")
      System.put_env("SKIP_TERMBOX2_TESTS", "true")
      System.put_env("MIX_ENV", "test")

      Mix.Task.run("compile", ["--warnings-as-errors"])
      Mix.shell().info("    [OK] Compilation successful")
      {:compile, :ok}
    rescue
      e ->
        Mix.shell().error(
          "    [FAIL] Compilation failed: #{Exception.message(e)}"
        )

        {:compile, :error}
    end
  end

  defp run_check(:format) do
    Mix.shell().info("==> Checking code formatting...")

    case Mix.shell().cmd("mix format --check-formatted") do
      0 ->
        Mix.shell().info("    [OK] Code is properly formatted")
        {:format, :ok}

      _ ->
        Mix.shell().error("    [FAIL] Code formatting issues found")
        Mix.shell().info("    Run 'mix format' to fix")
        {:format, :warning}
    end
  end

  defp run_check(:credo) do
    Mix.shell().info("==> Running Credo analysis...")

    case Code.ensure_loaded?(Credo) do
      true ->
        case Mix.shell().cmd("mix credo --strict") do
          0 ->
            Mix.shell().info("    [OK] Credo analysis passed")
            {:credo, :ok}

          _ ->
            Mix.shell().error("    [FAIL] Credo found issues")
            {:credo, :warning}
        end

      false ->
        Mix.shell().info("    [WARN] Credo not available")
        {:credo, :skipped}
    end
  end

  defp run_check(:dialyzer) do
    Mix.shell().info("==> Running Dialyzer...")

    case Code.ensure_loaded?(Dialyxir) do
      true ->
        case Mix.shell().cmd("mix dialyzer") do
          0 ->
            Mix.shell().info("    [OK] Dialyzer analysis passed")
            {:dialyzer, :ok}

          _ ->
            Mix.shell().error("    [FAIL] Dialyzer found issues")
            {:dialyzer, :warning}
        end

      false ->
        Mix.shell().info("    [WARN] Dialyzer not available")
        {:dialyzer, :skipped}
    end
  end

  defp run_check(:security) do
    Mix.shell().info("==> Running security audit...")

    case Code.ensure_loaded?(Sobelow) do
      true ->
        case Mix.shell().cmd("mix sobelow --config") do
          0 ->
            Mix.shell().info("    [OK] Security audit passed")
            {:security, :ok}

          _ ->
            Mix.shell().error("    [FAIL] Security issues found")
            {:security, :warning}
        end

      false ->
        Mix.shell().info("    [WARN] Sobelow not available")
        {:security, :skipped}
    end
  end

  defp run_check(:test) do
    Mix.shell().info("==> Running test suite...")

    System.put_env("TMPDIR", "/tmp")
    System.put_env("SKIP_TERMBOX2_TESTS", "true")
    System.put_env("MIX_ENV", "test")

    # Exclude slow tests and benchmarks
    case Mix.shell().cmd(
           "mix test --exclude slow --exclude integration --exclude docker --exclude benchmark --exclude skip_on_ci --max-failures 10"
         ) do
      0 ->
        Mix.shell().info("    [OK] All tests passed")
        {:test, :ok}

      _ ->
        Mix.shell().error("    [FAIL] Some tests failed")
        {:test, :error}
    end
  end

  defp run_check(unknown) do
    Mix.shell().error("Unknown check: #{unknown}")
    {unknown, :error}
  end

  defp print_summary(results) do
    Mix.shell().info("")
    Mix.shell().info("=================")
    Mix.shell().info("Check Summary:")
    Mix.shell().info("=================")

    Enum.each(results, fn {check, status} ->
      status_str =
        case status do
          :ok -> "[OK] PASSED"
          :warning -> "[WARN] WARNING"
          :error -> "[FAIL] FAILED"
          :skipped -> "[SKIP] SKIPPED"
        end

      Mix.shell().info("  #{check}: #{status_str}")
    end)

    Mix.shell().info("")
  end
end
