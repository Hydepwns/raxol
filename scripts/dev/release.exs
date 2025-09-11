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

    # Clean previous builds for consistency
    if opts[:clean] != false, do: clean_builds()

    results = for platform <- platforms do
      build_for_platform(platform, env)
    end

    # Summary of build results
    successful = Enum.count(results, & &1 == :ok)
    total = length(results)

    IO.puts "\n=== Build Summary ==="
    IO.puts "✅ Successful: #{successful}/#{total}"
    if successful < total, do: IO.puts "❌ Failed: #{total - successful}/#{total}"
    
    IO.puts "Release artifacts available in burrito_out/#{env}/"
    create_artifact_manifest(env, platforms, results)
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
        :ok
      {_, error_code} ->
        IO.puts "❌ Failed to build #{@app_name} for #{platform} with exit code #{error_code}"
        :error
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

    # Check if working directory is clean
    {status_output, _} = System.cmd("git", ["status", "--porcelain"])
    if String.trim(status_output) != "" do
      IO.puts "⚠️  Working directory has uncommitted changes:"
      IO.puts status_output
      IO.puts "Please commit or stash changes before tagging."
      System.halt(1)
    end

    # Check if tag already exists
    case System.cmd("git", ["tag", "-l", "v#{@version}"]) do
      {output, 0} when output != "" ->
        IO.puts "⚠️  Tag v#{@version} already exists. Use 'git tag -d v#{@version}' to delete it first."
        System.halt(1)
      _ -> :ok
    end

    # Create annotated tag with release notes
    tag_message = "Release v#{@version}\n\nBuilt with Raxol Release Script\nBuild date: #{DateTime.utc_now() |> DateTime.to_iso8601()}"
    
    commands = [
      {"git tag -a v#{@version} -m \"#{tag_message}\"", "Creating tag"},
      {"git push origin v#{@version}", "Pushing tag to origin"}
    ]

    for {command, description} <- commands do
      IO.puts "#{description}..."
      case System.cmd("sh", ["-c", command]) do
        {_, 0} -> 
          IO.puts "✅ #{description} completed"
        {output, error_code} ->
          IO.puts "❌ #{description} failed with exit code #{error_code}"
          IO.puts "Output: #{String.trim(output)}"
          System.halt(1)
      end
    end

    IO.puts "✅ Version v#{@version} tagged and pushed successfully"
  end

  defp create_artifact_manifest(env, platforms, results) do
    manifest_path = "burrito_out/#{env}/MANIFEST.json"
    
    manifest = %{
      app: @app_name,
      version: @version,
      environment: env,
      build_time: DateTime.utc_now() |> DateTime.to_iso8601(),
      platforms: Enum.zip(platforms, results) |> Enum.map(fn {platform, result} ->
        %{
          platform: platform,
          status: if(result == :ok, do: "success", else: "failed"),
          executable: get_executable_name(platform, env)
        }
      end)
    }

    File.mkdir_p!(Path.dirname(manifest_path))
    File.write!(manifest_path, Jason.encode!(manifest, pretty: true))
    IO.puts "📋 Build manifest created: #{manifest_path}"
  end

  defp get_executable_name(platform, env) do
    suffix = if env == "dev", do: "_dev", else: ""
    case platform do
      :windows -> "raxol#{suffix}.exe"
      _ -> "raxol#{suffix}"
    end
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
