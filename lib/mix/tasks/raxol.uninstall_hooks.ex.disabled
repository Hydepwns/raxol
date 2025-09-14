defmodule Mix.Tasks.Raxol.UninstallHooks do
  @moduledoc """
  Uninstall Raxol Git hooks.

  This task removes the Raxol pre-commit hook from your Git repository.

  ## Usage

      mix raxol.uninstall_hooks
      
  ## Options

    * `--force` - Remove without confirmation
    * `--restore` - Restore from backup if available
    
  ## Examples

      # Uninstall hooks (interactive)
      mix raxol.uninstall_hooks
      
      # Force removal without confirmation
      mix raxol.uninstall_hooks --force
      
      # Restore from backup
      mix raxol.uninstall_hooks --restore
  """

  use Mix.Task

  @shortdoc "Uninstall Git pre-commit hooks"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          force: :boolean,
          restore: :boolean
        ]
      )

    git_dir = get_git_directory()
    hooks_dir = Path.join(git_dir, "hooks")
    pre_commit_path = Path.join(hooks_dir, "pre-commit")

    case File.exists?(pre_commit_path) do
      true ->
        handle_uninstall(pre_commit_path, hooks_dir, opts)

      false ->
        IO.puts("ℹ️  No pre-commit hook found to uninstall")
        {:ok, :not_found}
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

  defp handle_uninstall(hook_path, hooks_dir, opts) do
    content = File.read!(hook_path)

    cond do
      # Check if it's our hook
      String.contains?(content, "Raxol pre-commit hook") ->
        uninstall_raxol_hook(hook_path, hooks_dir, opts)

      # Check if it mentions raxol at all
      String.contains?(content, "mix raxol.pre_commit") ->
        IO.puts("⚠️  Found a custom hook that includes Raxol commands")
        IO.puts("    This appears to be a manually integrated hook.")

        case opts[:force] || prompt_user("Remove entire hook?") do
          true ->
            remove_hook(hook_path, hooks_dir, opts)

          false ->
            IO.puts(
              "Uninstall cancelled. Please manually remove Raxol integration from your hook."
            )

            {:ok, :cancelled}
        end

      # Not a Raxol hook
      true ->
        IO.puts("ℹ️  The current pre-commit hook is not a Raxol hook")
        IO.puts("    No action taken.")
        {:ok, :not_raxol}
    end
  end

  defp uninstall_raxol_hook(hook_path, hooks_dir, opts) do
    case opts[:force] || prompt_user("Remove Raxol pre-commit hook?") do
      true ->
        remove_hook(hook_path, hooks_dir, opts)

      false ->
        IO.puts("Uninstall cancelled")
        {:ok, :cancelled}
    end
  end

  defp remove_hook(hook_path, hooks_dir, opts) do
    # Check for restore option
    case opts[:restore] do
      true ->
        restore_backup(hook_path, hooks_dir)

      false ->
        File.rm!(hook_path)
        IO.puts("✅ Successfully removed pre-commit hook")
        {:ok, :removed}
    end
  end

  defp restore_backup(hook_path, hooks_dir) do
    # Find most recent backup
    backup_pattern = Path.join(hooks_dir, "pre-commit.backup.*")

    case Path.wildcard(backup_pattern) |> Enum.sort() |> List.last() do
      nil ->
        IO.puts("❌ No backup found to restore")
        IO.puts("    Removing current hook without restoration")
        File.rm!(hook_path)
        {:ok, :removed_no_backup}

      backup_path ->
        File.rm!(hook_path)
        File.copy!(backup_path, hook_path)

        # Make it executable
        System.cmd("chmod", ["+x", hook_path])

        IO.puts("✅ Restored pre-commit hook from backup")
        IO.puts("    Backup: #{Path.basename(backup_path)}")

        # Optionally remove the backup
        case prompt_user("Remove backup file?") do
          true -> File.rm!(backup_path)
          false -> :ok
        end

        {:ok, :restored}
    end
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
end
