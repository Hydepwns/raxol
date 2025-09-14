defmodule Mix.Tasks.Raxol.Check.Dialyzer do
  @moduledoc """
  Run Dialyzer type checking with smart PLT caching.

  This task provides fast Dialyzer checks by:
  - Caching PLT files for dependencies
  - Only checking changed modules
  - Smart invalidation when deps change

  ## Features

  - Incremental PLT building
  - Dependency change detection
  - Fast incremental checks
  - Clear error reporting

  ## Options

  - `--build-plt` - Force rebuild PLT file
  - `--check-plt` - Verify PLT is up-to-date
  - `--all` - Check all files, not just changed
  - `--verbose` - Show detailed output
  """

  use Mix.Task
  alias Raxol.PreCommit.GitHelper

  @shortdoc "Run Dialyzer type checking"
  @plt_path ".raxol_cache/dialyzer.plt"
  @deps_hash_path ".raxol_cache/dialyzer_deps.hash"

  @impl Mix.Task
  def run(config \\ %{}) do
    verbose = Map.get(config, :verbose, false)
    build_plt = Map.get(config, :build_plt, false)
    check_plt = Map.get(config, :check_plt, false)
    check_all = Map.get(config, :all, false)

    # Ensure cache directory exists
    ensure_cache_dir()

    # Check if Dialyzer is available
    case ensure_dialyzer() do
      :ok ->
        run_dialyzer_check(build_plt, check_plt, check_all, verbose)

      {:error, reason} ->
        {:warning, "Dialyzer not available: #{reason}"}
    end
  end

  defp ensure_cache_dir do
    Path.dirname(@plt_path) |> File.mkdir_p!()
  end

  defp ensure_dialyzer do
    case System.find_executable("dialyzer") do
      nil ->
        {:error,
         "Dialyzer not found. Install Erlang/OTP with Dialyzer support."}

      _path ->
        :ok
    end
  end

  defp run_dialyzer_check(build_plt, check_plt, check_all, verbose) do
    # Handle PLT operations
    plt_result = handle_plt(build_plt, check_plt, verbose)

    case plt_result do
      {:error, reason} ->
        {:error, reason}

      :ok ->
        # Get files to check
        files = get_files_to_check(check_all)

        case files do
          [] ->
            maybe_log(verbose, "No files to check with Dialyzer")
            {:ok, "No files to check"}

          files ->
            maybe_log(
              verbose,
              "Checking #{length(files)} files with Dialyzer..."
            )

            check_files_with_dialyzer(files, verbose)
        end
    end
  end

  defp handle_plt(true, _check, verbose) do
    maybe_log(verbose, "Building PLT file...")
    build_plt_file(verbose)
  end

  defp handle_plt(_build, true, verbose) do
    maybe_log(verbose, "Checking PLT file...")
    check_plt_file(verbose)
  end

  defp handle_plt(_build, _check, verbose) do
    # Auto-handle PLT based on deps changes
    case plt_needs_rebuild?(verbose) do
      true ->
        maybe_log(verbose, "Dependencies changed, rebuilding PLT...")
        build_plt_file(verbose)

      false ->
        case File.exists?(@plt_path) do
          true ->
            maybe_log(verbose, "Using cached PLT file")
            :ok

          false ->
            maybe_log(verbose, "PLT file not found, building...")
            build_plt_file(verbose)
        end
    end
  end

  defp plt_needs_rebuild?(verbose) do
    current_deps_hash = calculate_deps_hash()

    case File.read(@deps_hash_path) do
      {:ok, stored_hash} ->
        needs_rebuild = stored_hash != current_deps_hash

        case needs_rebuild do
          true ->
            maybe_log(verbose, "Dependencies changed since last PLT build")

          false ->
            maybe_log(verbose, "Dependencies unchanged")
        end

        needs_rebuild

      {:error, _} ->
        # No hash file, needs rebuild
        true
    end
  end

  defp calculate_deps_hash do
    # Hash mix.lock and mix.exs to detect dep changes
    files_to_hash = ["mix.lock", "mix.exs"]

    content =
      files_to_hash
      |> Enum.map(fn file ->
        case File.read(file) do
          {:ok, content} -> content
          _ -> ""
        end
      end)
      |> Enum.join("\n")

    :crypto.hash(:sha256, content) |> Base.encode16()
  end

  defp build_plt_file(verbose) do
    # Get app and dependency beams
    app_beams = get_app_beams()
    deps_beams = get_deps_beams()

    all_beams = app_beams ++ deps_beams

    # Build PLT with progress indicator
    args =
      [
        "--build_plt",
        "--plt",
        @plt_path,
        "--apps",
        "erts",
        "kernel",
        "stdlib",
        "elixir"
      ] ++ all_beams

    maybe_log(verbose, "Building PLT with #{length(all_beams)} beam files...")

    case run_dialyzer_command(args, verbose, 120_000) do
      {:ok, _output} ->
        # Save deps hash for future comparison
        deps_hash = calculate_deps_hash()
        File.write!(@deps_hash_path, deps_hash)

        maybe_log(verbose, "PLT built successfully")
        :ok

      {:error, output} ->
        {:error, "Failed to build PLT:\n#{output}"}
    end
  end

  defp check_plt_file(verbose) do
    case File.exists?(@plt_path) do
      false ->
        build_plt_file(verbose)

      true ->
        args = ["--check_plt", "--plt", @plt_path]

        case run_dialyzer_command(args, verbose, 30_000) do
          {:ok, _} ->
            maybe_log(verbose, "PLT is up-to-date")
            :ok

          {:error, output} ->
            case String.contains?(output, "rebuild") do
              true ->
                maybe_log(verbose, "PLT needs rebuild")
                build_plt_file(verbose)

              false ->
                {:error, "PLT check failed:\n#{output}"}
            end
        end
    end
  end

  defp check_files_with_dialyzer(files, verbose) do
    args =
      [
        "--plt",
        @plt_path,
        "--no_check_plt",
        "-Wunmatched_returns",
        "-Werror_handling",
        "-Wrace_conditions"
      ] ++ files

    case run_dialyzer_command(args, verbose, 60_000) do
      {:ok, output} ->
        # Even successful runs might have warnings
        warnings = parse_dialyzer_output(output)

        case warnings do
          [] ->
            {:ok, "Dialyzer found no issues"}

          warnings ->
            # Return as warning, not error, for non-critical issues
            {:warning, format_dialyzer_warnings(warnings)}
        end

      {:error, output} ->
        errors = parse_dialyzer_output(output)
        {:error, %{errors: errors, raw_output: output}}
    end
  end

  defp get_files_to_check(true) do
    # Check all project files
    Path.wildcard("lib/**/*.ex")
  end

  defp get_files_to_check(false) do
    # Only check staged files
    case GitHelper.get_staged_elixir_files() do
      {:ok, files} ->
        files
        |> Enum.filter(&String.starts_with?(&1, "lib/"))
        |> Enum.filter(&File.exists?/1)

      _ ->
        []
    end
  end

  defp get_app_beams do
    app = Mix.Project.config()[:app]
    build_path = Mix.Project.build_path()

    Path.wildcard("#{build_path}/lib/#{app}/ebin/*.beam")
  end

  defp get_deps_beams do
    build_path = Mix.Project.build_path()

    Path.wildcard("#{build_path}/lib/*/ebin/*.beam")
    |> Enum.reject(fn path ->
      # Exclude our app's beams
      app = Mix.Project.config()[:app] |> to_string()
      String.contains?(path, "/#{app}/ebin/")
    end)
  end

  defp run_dialyzer_command(args, verbose, timeout) do
    task =
      Task.async(fn ->
        System.cmd("dialyzer", args, stderr_to_stdout: true)
      end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, {output, 0}} ->
        maybe_log_output(output, verbose)
        {:ok, output}

      {:ok, {output, _exit_code}} ->
        maybe_log_output(output, verbose)
        {:error, output}

      nil ->
        {:error, "Dialyzer timed out after #{timeout}ms"}
    end
  end

  defp parse_dialyzer_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ".ex:"))
    |> Enum.map(fn line ->
      case Regex.run(~r/([^:]+):(\d+):(.+)/, line) do
        [_, file, line_num, message] ->
          %{
            file: file,
            line: String.to_integer(line_num),
            message: String.trim(message)
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp format_dialyzer_warnings(warnings) do
    count = length(warnings)

    details =
      warnings
      |> Enum.take(5)
      |> Enum.map(fn w ->
        "  • #{w.file}:#{w.line}\n    #{w.message}"
      end)
      |> Enum.join("\n\n")

    more =
      case count > 5 do
        true -> "\n\n  ... and #{count - 5} more warnings"
        false -> ""
      end

    """
    Dialyzer found #{count} warning(s):

    #{details}#{more}

    Run 'mix dialyzer' for full output
    """
  end

  defp maybe_log(false, _msg), do: :ok
  defp maybe_log(true, msg), do: IO.puts("  #{msg}")

  defp maybe_log_output(_output, false), do: :ok

  defp maybe_log_output(output, true) do
    # Only show first 20 lines in verbose mode
    output
    |> String.split("\n")
    |> Enum.take(20)
    |> Enum.each(&IO.puts/1)
  end
end
