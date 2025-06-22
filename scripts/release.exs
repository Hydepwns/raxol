#!/usr/bin/env elixir

# Raxol Release Script
# This script handles building releases using Burrito for different platforms and environments

defmodule Raxol.Release do
  @moduledoc """
  Release script for Raxol using Burrito.
  Handles building binaries for different platforms and environments.
  """

  @app_name "raxol"
  @version Mix.Project.config[:version]

  def main(args) do
    {opts, _, _} = OptionParser.parse(args,
      strict: [
        help: :boolean,
        env: :string,
        platform: :string,
        all: :boolean,
        clean: :boolean,
        tag: :boolean
      ],
      aliases: [
        h: :help,
        e: :env,
        p: :platform,
        a: :all,
        c: :clean,
        t: :tag
      ]
    )

    case opts do
      [help: true] -> print_help()
      [clean: true] -> clean_builds()
      [tag: true] -> create_version_tag()
      _ -> build_release(opts)
    end
  end

  def build_release(opts) do
    env = opts[:env] || "dev"
    platforms = get_platforms(opts)

    IO.puts "Building #{@app_name} #{@version} for environment: #{env}"
    IO.puts "Target platforms: #{inspect platforms}"

    for platform <- platforms do
      build_for_platform(platform, env)
    end

    IO.puts "\nBuild complete!"
    IO.puts "Release artifacts available in burrito_out/#{env}/"
  end

  defp build_for_platform(platform, env) do
    IO.puts "\n=== Building for #{platform} in #{env} mode ==="

    # Set environment variable for Burrito to detect platform
    System.put_env("BURRITO_TARGET", to_string(platform))
    System.put_env("MIX_ENV", env)

    # Run the build command
    command = "mix burrito.build --env #{env}"
    IO.puts "Executing: #{command}"

    case System.cmd("sh", ["-c", command], into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        IO.puts "✅ Successfully built #{@app_name} for #{platform} in #{env} mode"
      {_, error_code} ->
        IO.puts "❌ Failed to build #{@app_name} for #{platform} with exit code #{error_code}"
    end
  end

  defp get_platforms(opts) do
    case {opts[:platform], opts[:all]} do
      {nil, true} -> [:macos, :linux, :windows]
      {platform, _} when not nil?(platform) -> [String.to_atom(platform)]
      _ -> [current_platform()]
    end
  end

  defp current_platform do
    case :os.type() do
      {:unix, :darwin} -> :macos
      {:unix, _} -> :linux
      {:win32, _} -> :windows
      _ -> :unknown
    end
  end

  defp clean_builds do
    IO.puts "Cleaning up previous builds..."
    File.rm_rf!("burrito_out")
    IO.puts "✅ Build directory cleaned"
  end

  defp create_version_tag do
    IO.puts "Creating git tag for version #{@version}..."

    commands = [
      "git add .",
      "git commit -m \"Release v#{@version}\"",
      "git tag -a v#{@version} -m \"Version #{@version}\"",
      "git push origin v#{@version}"
    ]

    for command <- commands do
      IO.puts "Executing: #{command}"
      case System.cmd("sh", ["-c", command], into: IO.stream(:stdio, :line)) do
        {_, 0} -> :ok
        {_, error_code} ->
          IO.puts "❌ Command failed with exit code #{error_code}"
          IO.puts "Aborting version tagging process."
          System.halt(1)
      end
    end

    IO.puts "✅ Version #{@version} tagged and pushed successfully"
  end

  defp print_help do
    """
    Raxol Release Script

    Usage:
      mix run scripts/release.exs [options]

    Options:
      -h, --help             Show this help message
      -e, --env ENV          Set build environment (dev, prod) [default: dev]
      -p, --platform PLAT    Build for specific platform (macos, linux, windows)
      -a, --all              Build for all platforms
      -c, --clean            Clean build directories
      -t, --tag              Create and push git tag for current version

    Examples:
      # Build for current platform in development mode
      mix run scripts/release.exs

      # Build production release for all platforms
      mix run scripts/release.exs --env prod --all

      # Clean build directory and build for macOS
      mix run scripts/release.exs --clean --platform macos

      # Create a version tag and push to remote
      mix run scripts/release.exs --tag
    """
    |> IO.puts()
  end
end

# Execute the script
Raxol.Release.main(System.argv())
