defmodule ExampleDSLBenchmark do
  @moduledoc """
  Example benchmark using the new DSL to demonstrate the world-class benchmarking system.
  """

  use Raxol.Benchmark.DSL

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ANSI.Parser
  alias Raxol.Terminal.ANSI.StateMachine

  benchmark_suite "Parser Performance with DSL" do
    setup do
      emulator = Emulator.new(80, 24)
      state_machine = StateMachine.new()
      {:ok, emulator: emulator, state_machine: state_machine}
    end

    scenario "parse_simple_text", %{state_machine: state_machine} do
      Parser.parse(state_machine, "Hello, World!")
    end

    scenario "parse_ansi_colors", %{state_machine: state_machine} do
      Parser.parse(state_machine, "\e[31mRed \e[32mGreen \e[34mBlue\e[0m")
    end

    scenario "parse_cursor_movement", %{state_machine: state_machine} do
      Parser.parse(state_machine, "\e[10;20H\e[5A\e[3B\e[2C")
    end

    parameterized_scenario "parse_color_range",
      %{
        "8_colors" => 8,
        "16_colors" => 16,
        "256_colors" => 256
      },
      %{state_machine: state_machine} do
      text = Enum.map(0..input, fn i ->
        "\e[38;5;#{rem(i, 256)}m█"
      end) |> Enum.join()

      Parser.parse(state_machine, text)
    end

    # Performance assertions
    assert_performance :parse_simple_text, faster_than: 5_000  # nanoseconds
    assert_performance :parse_ansi_colors, faster_than: 10_000
    assert_memory :all, less_than: 1_000_000  # bytes

    # Benchmark configuration
    benchmark_config(
      time: 3,
      warmup: 1,
      memory_time: 1
    )

    # Compare with baseline
    compare_with baseline: "v1.4.0"

    # Tag scenarios for filtering
    tag [:parser, :core]
  end

  benchmark_suite "Terminal Emulator Operations" do
    setup do
      {:ok, sizes: [{80, 24}, {120, 40}, {200, 50}]}
    end

    parameterized_scenario "create_emulator",
      %{
        "small" => {80, 24},
        "medium" => {120, 40},
        "large" => {200, 50}
      },
      _context do
      {width, height} = input
      Emulator.new(width, height)
    end

    scenario_group "Buffer Operations" do
      scenario "write_character", _context do
        emulator = Emulator.new(80, 24)
        {emulator, _output} = Emulator.process_input(emulator, "A")
        emulator
      end

      scenario "write_line", _context do
        emulator = Emulator.new(80, 24)
        {emulator, _output} = Emulator.process_input(emulator, "Hello, World!\n")
        emulator
      end

      scenario "scroll_buffer", _context do
        emulator = Emulator.new(80, 24)
        # Fill buffer to trigger scrolling
        text = Enum.map(1..30, fn i -> "Line #{i}\n" end) |> Enum.join()
        {emulator, _output} = Emulator.process_input(emulator, text)
        emulator
      end
    end

    profile_memory()
    profile_cpu()

    collect_metrics [:execution_time, :memory_allocated, :gc_runs]
  end

  benchmark_suite "Real-World Scenarios" do
    setup do
      alias Raxol.Benchmark.ScenarioGenerator
      scenarios = ScenarioGenerator.generate_real_world_scenarios()
      emulator = Emulator.new(80, 24)
      {:ok, emulator: emulator, scenarios: scenarios}
    end

    scenario "vim_editing_session", %{emulator: emulator, scenarios: scenarios} do
      {emulator, _} = Emulator.process_input(emulator, scenarios.vim_session)
      emulator
    end

    scenario "git_diff_display", %{emulator: emulator, scenarios: scenarios} do
      {emulator, _} = Emulator.process_input(emulator, scenarios.git_diff)
      emulator
    end

    scenario "npm_install_output", %{emulator: emulator, scenarios: scenarios} do
      {emulator, _} = Emulator.process_input(emulator, scenarios.npm_install)
      emulator
    end

    # Use property-based testing for random input
    property_based "random_ansi_sequences", fn ->
      # Generate random ANSI sequence
      sequences = ["\e[", "31m", "1;", "H", "J", "K", "A", "B", "C", "D"]
      Enum.take_random(sequences, 3) |> Enum.join()
    end do
      %{state_machine: StateMachine.new()} = context = setup.()
      Parser.parse(context.state_machine, input)
    end

    benchmark_config(
      time: 5,
      warmup: 2,
      memory_time: 2,
      parallel: 2
    )
  end
end

# Module to run the example benchmark
defmodule RunExampleBenchmark do
  def run do
    IO.puts("\n🚀 Running Example Benchmark with New DSL\n")

    # Run the benchmarks
    results = ExampleDSLBenchmark.run_benchmarks()

    # Display results
    IO.puts("\n✅ Benchmark completed successfully!")
    IO.puts("\nResults have been saved to bench/output/")

    results
  end
end