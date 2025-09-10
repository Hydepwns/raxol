defmodule Mix.Tasks.Raxol.UpdateHooks do
  @moduledoc """
  Update Raxol Git hooks to the latest version.

  This task updates existing Raxol pre-commit hooks to the latest version,
  preserving any custom modifications when possible.

  ## Usage

      mix raxol.update_hooks
      
  ## Options

    * `--force` - Force update without confirmation
    * `--backup` - Create backup before updating
    * `--check` - Check if updates are available (dry run)
    
  ## Examples

      # Update hooks (interactive)
      mix raxol.update_hooks
      
      # Check for updates without installing
      mix raxol.update_hooks --check
      
      # Force update with backup
      mix raxol.update_hooks --force --backup
  """

  use Mix.Task

  @shortdoc "Update Git hooks to latest version"

  # Import the hook content from install task
  alias Mix.Tasks.Raxol.InstallHooks

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          force: :boolean,
          backup: :boolean,
          check: :boolean
        ]
      )

    git_dir = get_git_directory()
    hooks_dir = Path.join(git_dir, "hooks")
    pre_commit_path = Path.join(hooks_dir, "pre-commit")

    case File.exists?(pre_commit_path) do
      true ->
        handle_update(pre_commit_path, opts)

      false ->
        IO.puts("❌ No pre-commit hook installed")

        case opts[:check] do
          true ->
            IO.puts("    Run 'mix raxol.install_hooks' to install")
            {:ok, :not_installed}

          false ->
            IO.puts("    Installing new hook...")
            InstallHooks.run([])
        end
    end
  end

  defp get_git_directory do
    case System.cmd("git", ["rev-parse", "--git-dir"], stderr_to_stdout: true) do
      {output, 0} ->
        String.trim(output)

      _ ->
        Mix.raise(
          "Not in a Git repository. Please run this command from a Git repository."
        )
    end
  end

  defp handle_update(hook_path, opts) do
    current_content = File.read!(hook_path)
    latest_content = get_latest_hook_content()

    cond do
      # Already up to date
      current_content == latest_content ->
        IO.puts("✅ Raxol pre-commit hook is already up to date")
        {:ok, :current}

      # Check only mode
      opts[:check] ->
        check_for_updates(current_content, latest_content)

      # Not a Raxol hook
      not String.contains?(current_content, "mix raxol.pre_commit") ->
        IO.puts("⚠️  Current pre-commit hook is not a Raxol hook")
        IO.puts("    Run 'mix raxol.install_hooks' to install Raxol hook")
        {:ok, :not_raxol}

      # Custom modifications detected
      has_custom_modifications?(current_content) ->
        handle_custom_hook_update(
          hook_path,
          current_content,
          latest_content,
          opts
        )

      # Standard update
      true ->
        perform_update(hook_path, latest_content, opts)
    end
  end

  defp check_for_updates(current_content, latest_content) do
    case compare_versions(current_content, latest_content) do
      :newer ->
        IO.puts("🔄 Update available for Raxol pre-commit hook")
        IO.puts("    Run 'mix raxol.update_hooks' to update")

        show_changes(current_content, latest_content)
        {:ok, :update_available}

      :same ->
        IO.puts("✅ Raxol pre-commit hook is up to date")
        {:ok, :current}

      :custom ->
        IO.puts("ℹ️  Custom modifications detected in pre-commit hook")
        IO.puts("    Manual review recommended before updating")
        {:ok, :custom}
    end
  end

  defp has_custom_modifications?(content) do
    # Check if the hook has been modified from standard templates
    lines = String.split(content, "\n")

    # Look for signs of customization
    custom_indicators = [
      # User added comments (excluding our standard ones)
      ~r/^#(?!.*Raxol|.*Generated|.*Allow bypassing|.*Check if|.*Run the|.*Capture|.*Exit)/,
      # Additional commands before our check
      ~r/^(?!#|if|echo|mix raxol|EXIT_CODE|exit)/,
      # Custom environment variables
      ~r/export (?!RAXOL_)/
    ]

    Enum.any?(lines, fn line ->
      Enum.any?(custom_indicators, &Regex.match?(&1, line))
    end)
  end

  defp handle_custom_hook_update(
         hook_path,
         current_content,
         latest_content,
         opts
       ) do
    IO.puts("⚠️  Custom modifications detected in your pre-commit hook")
    IO.puts("")

    IO.puts(
      "Your hook contains custom code that would be lost with a standard update."
    )

    show_custom_sections(current_content)

    IO.puts("")
    IO.puts("Options:")
    IO.puts("  1. Backup current and install fresh (recommended)")
    IO.puts("  2. Keep current hook (no update)")
    IO.puts("  3. Show diff and decide")

    case opts[:force] do
      true ->
        maybe_backup(hook_path, opts)
        perform_update(hook_path, latest_content, opts)

      false ->
        handle_custom_update_choice(
          hook_path,
          current_content,
          latest_content,
          opts
        )
    end
  end

  defp handle_custom_update_choice(
         hook_path,
         current_content,
         latest_content,
         opts
       ) do
    choice =
      case IO.gets("Choose option [1-3]: ") do
        # Default to keeping current
        :eof -> "2"
        response when is_binary(response) -> String.trim(response)
        _ -> "2"
      end

    case choice do
      "1" ->
        maybe_backup(hook_path, true)
        perform_update(hook_path, latest_content, opts)

      "2" ->
        IO.puts("Update cancelled. Current hook preserved.")
        {:ok, :kept_current}

      "3" ->
        show_diff(current_content, latest_content)

        case prompt_user("Proceed with update?") do
          true ->
            maybe_backup(hook_path, opts)
            perform_update(hook_path, latest_content, opts)

          false ->
            IO.puts("Update cancelled")
            {:ok, :cancelled}
        end

      _ ->
        IO.puts("Invalid choice. Update cancelled.")
        {:ok, :cancelled}
    end
  end

  defp perform_update(hook_path, new_content, opts) do
    maybe_backup(hook_path, opts)

    File.write!(hook_path, new_content)
    System.cmd("chmod", ["+x", hook_path])

    IO.puts("✅ Successfully updated Raxol pre-commit hook")
    IO.puts("    Your hook is now at the latest version")

    {:ok, :updated}
  end

  defp maybe_backup(hook_path, %{backup: true}),
    do: maybe_backup(hook_path, true)

  defp maybe_backup(_hook_path, %{backup: false}), do: :ok
  defp maybe_backup(_hook_path, false), do: :ok

  defp maybe_backup(hook_path, true) do
    backup_path = "#{hook_path}.backup.#{timestamp()}"
    File.copy!(hook_path, backup_path)
    IO.puts("📦 Created backup: #{Path.basename(backup_path)}")
  end

  defp get_latest_hook_content do
    # This would normally fetch from the module attribute in InstallHooks
    # For now, we'll duplicate it here (in production, share via a common module)
    """
    #!/bin/sh
    # Raxol pre-commit hook
    # Generated by mix raxol.install_hooks

    # Allow bypassing the hook with RAXOL_SKIP_CHECKS environment variable
    if [ "$RAXOL_SKIP_CHECKS" = "true" ] || [ "$RAXOL_SKIP_CHECKS" = "1" ]; then
      echo "Skipping Raxol pre-commit checks (RAXOL_SKIP_CHECKS is set)"
      exit 0
    fi

    # Check if we're in a rebase
    if [ -d "$(git rev-parse --git-dir)/rebase-merge" ] || [ -d "$(git rev-parse --git-dir)/rebase-apply" ]; then
      echo "Skipping pre-commit checks during rebase"
      exit 0
    fi

    # Run the pre-commit checks
    echo "Running Raxol pre-commit checks..."
    mix raxol.pre_commit

    # Capture the exit code
    EXIT_CODE=$?

    # Exit with the same code
    if [ $EXIT_CODE -ne 0 ]; then
      echo ""
      echo "Pre-commit checks failed. You can bypass with:"
      echo "  git commit --no-verify"
      echo "  RAXOL_SKIP_CHECKS=true git commit"
    fi

    exit $EXIT_CODE
    """
  end

  defp compare_versions(current, latest) do
    # Simple version comparison based on content
    cond do
      current == latest ->
        :same

      String.contains?(current, "mix raxol.pre_commit") and
          not String.contains?(current, "Generated by mix raxol.install_hooks") ->
        :custom

      true ->
        :newer
    end
  end

  defp show_changes(_current, _latest) do
    IO.puts("")
    IO.puts("Changes in the latest version:")
    IO.puts("  • Improved error messages")
    IO.puts("  • Better rebase detection")
    IO.puts("  • Enhanced bypass options")
  end

  defp show_custom_sections(content) do
    lines = String.split(content, "\n")

    custom_lines =
      lines
      |> Enum.with_index()
      |> Enum.filter(fn {line, _} ->
        not String.starts_with?(line, "#") and
          line != "" and
          not String.contains?(line, "mix raxol.pre_commit") and
          not String.contains?(line, "RAXOL_SKIP_CHECKS") and
          not String.contains?(line, "EXIT_CODE")
      end)
      |> Enum.take(5)

    case custom_lines do
      [] ->
        :ok

      lines ->
        IO.puts("Custom sections detected:")

        Enum.each(lines, fn {line, num} ->
          IO.puts("  Line #{num + 1}: #{String.slice(line, 0, 60)}")
        end)
    end
  end

  defp show_diff(current, latest) do
    IO.puts("")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("CURRENT HOOK (first 20 lines):")
    IO.puts("-" |> String.duplicate(60))

    current
    |> String.split("\n")
    |> Enum.take(20)
    |> Enum.each(&IO.puts/1)

    IO.puts("")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("LATEST VERSION (first 20 lines):")
    IO.puts("-" |> String.duplicate(60))

    latest
    |> String.split("\n")
    |> Enum.take(20)
    |> Enum.each(&IO.puts/1)

    IO.puts("=" |> String.duplicate(60))
  end

  defp prompt_user(question) do
    case IO.gets("#{question} [y/N]: ") do
      :eof ->
        false

      response when is_binary(response) ->
        response
        |> String.trim()
        |> String.downcase()
        |> then(&(&1 in ["y", "yes"]))

      _ ->
        false
    end
  end

  defp timestamp do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()
    "#{year}#{pad(month)}#{pad(day)}_#{pad(hour)}#{pad(minute)}#{pad(second)}"
  end

  defp pad(num), do: num |> Integer.to_string() |> String.pad_leading(2, "0")
end
