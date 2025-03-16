defmodule Raxol.CLI.Commands.UpdateCmd do
  @moduledoc """
  CLI command for managing Raxol updates.
  
  This module handles:
  - Checking for updates
  - Performing self-updates
  - Managing update settings
  """
  
  alias Raxol.System.Updater
  alias Raxol.Style.Colors.Color
  alias Raxol.Style.Colors.Adaptive
  
  @doc """
  Executes the update command with the provided options and arguments.
  
  ## Options
  
  - `--check` or `-c`: Check for updates without installing
  - `--force` or `-f`: Force update check, bypassing the check interval
  - `--auto` or `-a`: Enable or disable automatic update checks (value: on/off)
  - `--version` or `-v`: Update to a specific version
  - `--no-delta` or `-n`: Disable delta updates and use full updates only
  - `--delta-info` or `-d`: Show information about delta update availability

  ## Examples
  
  Check for updates:
  ```
  raxol update --check
  ```
  
  Perform an update:
  ```
  raxol update
  ```
  
  Update to a specific version:
  ```
  raxol update --version 0.2.0
  ```
  
  Update without using delta updates:
  ```
  raxol update --no-delta
  ```
  
  Disable automatic update checks:
  ```
  raxol update --auto off
  ```
  """
  def execute(args) do
    {opts, _, _} = OptionParser.parse(args,
      strict: [
        check: :boolean,
        force: :boolean,
        auto: :string,
        version: :string,
        help: :boolean,
        no_delta: :boolean,
        delta_info: :boolean
      ],
      aliases: [
        c: :check,
        f: :force,
        a: :auto,
        v: :version,
        h: :help,
        n: :no_delta,
        d: :delta_info
      ]
    )
    
    cond do
      opts[:help] ->
        print_help()
        
      opts[:auto] ->
        handle_auto_check(opts[:auto])
        
      opts[:check] ->
        check_for_updates(force: opts[:force])
        
      opts[:delta_info] ->
        show_delta_info(opts[:version], force: opts[:force])
        
      true ->
        perform_update(opts[:version], force: opts[:force], use_delta: !opts[:no_delta])
    end
  end
  
  defp handle_auto_check(value) do
    case String.downcase(value) do
      "on" ->
        Updater.set_auto_check(true)
        IO.puts(success_msg("Automatic update checks are now enabled"))
        
      "off" ->
        Updater.set_auto_check(false)
        IO.puts(success_msg("Automatic update checks are now disabled"))
        
      _ ->
        IO.puts(error_msg("Invalid value for --auto. Use 'on' or 'off'"))
    end
  end
  
  defp check_for_updates(opts) do
    IO.puts("Checking for updates...")
    
    case Updater.check_for_updates(opts) do
      {:update_available, version} ->
        IO.puts(success_msg("Update available: v#{version}"))
        IO.puts("Current version: v#{Application.spec(:raxol, :vsn)}")
        IO.puts("\nRun 'raxol update' to install the update")
        
      {:no_update, version} ->
        IO.puts(success_msg("Raxol is up to date (v#{version})"))
        
      {:error, reason} ->
        IO.puts(error_msg("Error checking for updates: #{reason}"))
    end
  end
  
  defp perform_update(version, opts) do
    # Extract options with defaults
    force = Keyword.get(opts, :force, false)
    use_delta = Keyword.get(opts, :use_delta, true)
    
    # First check if an update is available
    check_result = if is_nil(version) do
      # If no specific version is provided, check for updates
      IO.puts("Checking for updates...")
      Updater.check_for_updates(opts)
    else
      # If a specific version is provided, we'll try to update to it
      {:update_available, version}
    end
    
    case check_result do
      {:update_available, update_version} ->
        # Show if using delta updates
        if use_delta do
          IO.puts("Updating to version v#{update_version} (with delta updates if available)...")
        else
          IO.puts("Updating to version v#{update_version} (using full update)...")
        end
        
        case Updater.self_update(update_version, use_delta: use_delta) do
          :ok ->
            IO.puts(success_msg("Update successful!"))
            IO.puts("Raxol has been updated to v#{update_version}")
            IO.puts("Please restart Raxol to use the new version")
            
          {:no_update, current_version} ->
            IO.puts(success_msg("Already running version v#{current_version}"))
            
          {:error, reason} ->
            IO.puts(error_msg("Update failed: #{reason}"))
            IO.puts("\nYou can try downloading the latest version manually from:")
            IO.puts("https://github.com/username/raxol/releases/latest")
        end
        
      {:no_update, version} ->
        IO.puts(success_msg("Raxol is already up to date (v#{version})"))
        
      {:error, reason} ->
        IO.puts(error_msg("Error checking for updates: #{reason}"))
    end
  end
  
  defp show_delta_info(version, opts) do
    # If no specific version is provided, check for latest
    if is_nil(version) do
      IO.puts("Checking for updates...")
      case Updater.check_for_updates(opts) do
        {:update_available, latest_version} ->
          check_delta_for_version(latest_version)
          
        {:no_update, current_version} ->
          IO.puts(success_msg("Raxol is already up to date (v#{current_version})"))
          IO.puts("No delta update information available.")
          
        {:error, reason} ->
          IO.puts(error_msg("Error checking for updates: #{reason}"))
      end
    else
      # Check delta info for the specified version
      check_delta_for_version(version)
    end
  end
  
  defp check_delta_for_version(version) do
    IO.puts("Checking delta update availability for version v#{version}...")
    
    alias Raxol.System.DeltaUpdater
    case DeltaUpdater.check_delta_availability(version) do
      {:ok, delta_info} ->
        IO.puts(success_msg("Delta update available!"))
        IO.puts("Full package size: #{format_bytes(delta_info.full_size)}")
        IO.puts("Delta size: #{format_bytes(delta_info.delta_size)}")
        IO.puts("Space savings: #{delta_info.savings_percent}%")
        IO.puts("\nTo update using delta updates, run: raxol update")
        
      {:error, reason} ->
        IO.puts(error_msg("Delta update not available: #{reason}"))
        IO.puts("Full update will be used when updating to this version.")
    end
  end
  
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024*1024, do: "#{Float.round(bytes/1024, 2)} KB"
  defp format_bytes(bytes) when bytes < 1024*1024*1024, do: "#{Float.round(bytes/1024/1024, 2)} MB"
  defp format_bytes(bytes), do: "#{Float.round(bytes/1024/1024/1024, 2)} GB"
  
  defp success_msg(text) do
    text
    |> Color.colorize(:green)
    |> Adaptive.adapt_color()
  end
  
  defp error_msg(text) do
    text
    |> Color.colorize(:red)
    |> Adaptive.adapt_color()
  end
  
  defp print_help do
    help_text = """
    Raxol Update Command
    
    Usage: raxol update [options]
    
    Options:
      -c, --check              Check for updates without installing
      -f, --force              Force update check, bypassing the check interval
      -a, --auto on|off        Enable or disable automatic update checks
      -v, --version VERSION    Update to a specific version
      -n, --no-delta           Disable delta updates, use full updates only
      -d, --delta-info         Show information about delta update availability
      -h, --help               Show this help message
    
    Examples:
      raxol update                     # Check and install updates (with delta if available)
      raxol update --check             # Only check for updates
      raxol update --delta-info        # Check delta update availability
      raxol update --no-delta          # Update using full update only
      raxol update --version 0.2.0     # Update to version 0.2.0
      raxol update --auto off          # Disable automatic update checks
    """
    
    IO.puts(help_text)
  end
end 