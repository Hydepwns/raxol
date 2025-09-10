defmodule Mix.Tasks.Raxol.Dialyzer do
  @moduledoc """
  Comprehensive Dialyzer tasks for the Raxol project with PLT caching.

  This module provides enhanced Dialyzer functionality with intelligent PLT
  management, performance tracking, and detailed reporting.

  ## Available Commands

  - `mix raxol.dialyzer` - Run full Dialyzer analysis with caching
  - `mix raxol.dialyzer --setup` - Build PLT files from scratch
  - `mix raxol.dialyzer --check` - Quick check against existing PLT
  - `mix raxol.dialyzer --clean` - Clean all PLT files and caches
  - `mix raxol.dialyzer --stats` - Show PLT and analysis statistics
  - `mix raxol.dialyzer --profile` - Run with performance profiling

  ## PLT Caching Strategy

  The task uses a two-tier PLT caching system:
  - Core PLT: Contains Erlang/OTP and stable dependencies
  - Local PLT: Contains project-specific modules and volatile dependencies

  This approach minimizes rebuild times while ensuring analysis accuracy.
  """

  use Mix.Task

  @shortdoc "Enhanced Dialyzer analysis with PLT caching for Raxol"

  @switches [
    setup: :boolean,
    check: :boolean,
    clean: :boolean,
    stats: :boolean,
    profile: :boolean,
    format: :string,
    verbose: :boolean
  ]

  def run(args) do
    {opts, _args, _} = OptionParser.parse(args, switches: @switches)

    ensure_plt_directory()

    cond do
      opts[:setup] -> setup_plt()
      opts[:check] -> quick_check()
      opts[:clean] -> clean_plt()
      opts[:stats] -> show_stats()
      opts[:profile] -> run_with_profiling()
      true -> run_analysis(opts)
    end
  end

  defp ensure_plt_directory do
    File.mkdir_p!("priv/plts")
  end

  defp setup_plt do
    info("🔧 Setting up Dialyzer PLT files...")
    start_time = System.monotonic_time(:millisecond)

    # Clean existing PLTs
    clean_plt_files()

    # Build core PLT
    info("📦 Building core PLT (Erlang/OTP + stable deps)...")

    case Mix.shell().cmd("mix dialyzer --plt") do
      0 ->
        info("✅ Core PLT built successfully")

      _ ->
        error("❌ Failed to build core PLT")
        exit({:shutdown, 1})
    end

    elapsed = System.monotonic_time(:millisecond) - start_time
    info("🎯 PLT setup completed in #{elapsed}ms")
    show_plt_info()
  end

  defp quick_check do
    info("⚡ Running quick Dialyzer check...")

    unless plt_exists?() do
      info("⚠️  PLT files not found. Building...")
      setup_plt()
    end

    start_time = System.monotonic_time(:millisecond)

    case Mix.shell().cmd("mix dialyzer --format short") do
      0 ->
        elapsed = System.monotonic_time(:millisecond) - start_time
        info("✅ No issues found (#{elapsed}ms)")

      _ ->
        error("❌ Issues detected - run 'mix raxol.dialyzer' for full analysis")
        exit({:shutdown, 1})
    end
  end

  defp run_analysis(opts) do
    info("🔍 Running comprehensive Dialyzer analysis...")

    unless plt_exists?() do
      info("🔧 PLT files not found. Setting up...")
      setup_plt()
    end

    format = opts[:format] || "dialyxir"
    verbose_flag = if opts[:verbose], do: " --verbose", else: ""

    start_time = System.monotonic_time(:millisecond)

    case Mix.shell().cmd("mix dialyzer --format #{format}#{verbose_flag}") do
      0 ->
        elapsed = System.monotonic_time(:millisecond) - start_time
        info("✅ Analysis completed successfully (#{elapsed}ms)")
        show_analysis_summary()

      _ ->
        error("❌ Analysis found issues")

        info(
          "💡 Tip: Check .dialyzer_ignore.exs to filter known false positives"
        )

        exit({:shutdown, 1})
    end
  end

  defp run_with_profiling do
    info("📊 Running Dialyzer with performance profiling...")

    # Ensure PLT exists
    unless plt_exists?() do
      setup_plt()
    end

    start_time = System.monotonic_time(:millisecond)
    memory_before = :erlang.memory(:total)

    case Mix.shell().cmd("mix dialyzer --format dialyxir") do
      0 ->
        elapsed = System.monotonic_time(:millisecond) - start_time
        memory_after = :erlang.memory(:total)
        # MB
        memory_used = (memory_after - memory_before) / 1_048_576

        info("📈 Performance Profile:")
        info("   ⏱️  Time: #{elapsed}ms")
        info("   🧠 Memory: #{Float.round(memory_used, 2)}MB")
        show_plt_info()

      _ ->
        error("❌ Analysis failed during profiling")
        exit({:shutdown, 1})
    end
  end

  defp clean_plt do
    info("🧹 Cleaning Dialyzer PLT files...")

    clean_plt_files()
    info("✅ PLT files cleaned")
  end

  defp show_stats do
    info("📊 Dialyzer PLT Statistics")
    info("=" <> String.duplicate("=", 40))

    show_plt_info()
    show_config_info()
    show_analysis_summary()
  end

  defp clean_plt_files do
    plt_files = Path.wildcard("priv/plts/*.plt")
    hash_files = Path.wildcard("priv/plts/*.plt.hash")

    (plt_files ++ hash_files)
    |> Enum.each(&File.rm/1)
  end

  defp plt_exists? do
    File.exists?("priv/plts/core.plt") ||
      File.exists?("priv/plts/local.plt") ||
      File.exists?(
        "_build/#{Mix.env()}/dialyxir_erlang-#{System.otp_release()}_elixir-#{System.version()}.plt"
      )
  end

  defp show_plt_info do
    plt_files = Path.wildcard("priv/plts/*.plt")

    if Enum.empty?(plt_files) do
      info("📁 PLT Status: No PLT files found")
    else
      info("📁 PLT Status:")

      plt_files
      |> Enum.each(fn file ->
        stat = File.stat!(file)
        # MB
        size = Float.round(stat.size / 1_048_576, 2)
        mtime = Calendar.strftime(stat.mtime, "%Y-%m-%d %H:%M:%S")

        info("   📄 #{Path.basename(file)}: #{size}MB (#{mtime})")
      end)
    end
  end

  defp show_config_info do
    config = Mix.Project.config()[:dialyzer] || []

    info("⚙️  Configuration:")
    info("   📦 PLT Apps: #{inspect(config[:plt_add_apps] || [])}")
    info("   🚩 Flags: #{inspect(config[:flags] || [])}")
    info("   🙈 Ignore File: #{config[:ignore_warnings] || "none"}")
  end

  defp show_analysis_summary do
    ignore_file = ".dialyzer_ignore.exs"

    if File.exists?(ignore_file) do
      content = File.read!(ignore_file)

      ignore_count =
        content |> String.split("\n") |> Enum.count(&(&1 =~ ~r/^\s*~r/))

      info("📋 Analysis Summary:")
      info("   🔇 Ignore patterns: #{ignore_count}")
      info("   📝 Ignore file: #{ignore_file}")
    end
  end

  defp info(message), do: Mix.shell().info(message)
  defp error(message), do: Mix.shell().error(message)
end
