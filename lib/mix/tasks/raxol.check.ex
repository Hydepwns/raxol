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

    if Enum.any?(results, fn {_, status} -> status != :ok end) do
      Mix.raise("Some checks failed")
    end
  end

  defp determine_checks(opts) do
    cond do
      opts[:only] ->
        parse_check_list(opts[:only])

      opts[:quick] ->
        @quick_checks

      true ->
        checks = @all_checks

        if opts[:skip] do
          skip = parse_check_list(opts[:skip])
          Enum.reject(checks, &(&1 in skip))
        else
          checks
        end
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
      Mix.shell().info("    ✓ Compilation successful")
      {:compile, :ok}
    rescue
      e ->
        Mix.shell().error("    ✗ Compilation failed: #{Exception.message(e)}")
        {:compile, :error}
    end
  end

  defp run_check(:format) do
    Mix.shell().info("==> Checking code formatting...")

    case Mix.shell().cmd("mix format --check-formatted") do
      0 ->
        Mix.shell().info("    ✓ Code is properly formatted")
        {:format, :ok}

      _ ->
        Mix.shell().error("    ✗ Code formatting issues found")
        Mix.shell().info("    Run 'mix format' to fix")
        {:format, :warning}
    end
  end

  defp run_check(:credo) do
    Mix.shell().info("==> Running Credo analysis...")

    if Code.ensure_loaded?(Credo) do
      case Mix.shell().cmd("mix credo --strict") do
        0 ->
          Mix.shell().info("    ✓ Credo analysis passed")
          {:credo, :ok}

        _ ->
          Mix.shell().error("    ✗ Credo found issues")
          {:credo, :warning}
      end
    else
      Mix.shell().info("    ⚠ Credo not available")
      {:credo, :skipped}
    end
  end

  defp run_check(:dialyzer) do
    Mix.shell().info("==> Running Dialyzer...")

    if Code.ensure_loaded?(Dialyxir) do
      case Mix.shell().cmd("mix dialyzer") do
        0 ->
          Mix.shell().info("    ✓ Dialyzer analysis passed")
          {:dialyzer, :ok}

        _ ->
          Mix.shell().error("    ✗ Dialyzer found issues")
          {:dialyzer, :warning}
      end
    else
      Mix.shell().info("    ⚠ Dialyzer not available")
      {:dialyzer, :skipped}
    end
  end

  defp run_check(:security) do
    Mix.shell().info("==> Running security audit...")

    if Code.ensure_loaded?(Sobelow) do
      case Mix.shell().cmd("mix sobelow --config") do
        0 ->
          Mix.shell().info("    ✓ Security audit passed")
          {:security, :ok}

        _ ->
          Mix.shell().error("    ✗ Security issues found")
          {:security, :warning}
      end
    else
      Mix.shell().info("    ⚠ Sobelow not available")
      {:security, :skipped}
    end
  end

  defp run_check(:test) do
    Mix.shell().info("==> Running test suite...")

    System.put_env("TMPDIR", "/tmp")
    System.put_env("SKIP_TERMBOX2_TESTS", "true")
    System.put_env("MIX_ENV", "test")

    case Mix.shell().cmd(
           "mix test --exclude slow --exclude integration --exclude docker"
         ) do
      0 ->
        Mix.shell().info("    ✓ All tests passed")
        {:test, :ok}

      _ ->
        Mix.shell().error("    ✗ Some tests failed")
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
          :ok -> "✓ PASSED"
          :warning -> "⚠ WARNING"
          :error -> "✗ FAILED"
          :skipped -> "⊘ SKIPPED"
        end

      Mix.shell().info("  #{check}: #{status_str}")
    end)

    Mix.shell().info("")
  end
end
