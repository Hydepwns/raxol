defmodule ParserBenchmark do
  @moduledoc "ANSI parser performance benchmarks."

  alias Raxol.Terminal.TerminalParser, as: Parser
  alias Raxol.Terminal.Emulator

  def run do
    emulator = Emulator.new(80, 24)

    # Test cases
    simple_text = "Hello, World!"
    
    ansi_colored = "\e[31mRed \e[32mGreen \e[34mBlue\e[0m Normal"
    
    complex_sequence = """
    \e[2J\e[H\e[1;1H\e[31;47mHeader\e[0m
    \e[2;1HLine 2 with \e[1mbold\e[0m and \e[4munderline\e[0m
    \e[3;1H\e[?25l\e[33mYellow text\e[0m\e[?25h
    """
    
    cursor_heavy = Enum.map(1..100, fn i ->
      "\e[#{i};1H\e[KLine #{i}"
    end) |> Enum.join("")
    
    large_text = String.duplicate("Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", 1000)
    
    Benchee.run(%{
      "simple_text" => fn -> Parser.parse(emulator, simple_text) end,
      "ansi_colored" => fn -> Parser.parse(emulator, ansi_colored) end,
      "complex_sequence" => fn -> Parser.parse(emulator, complex_sequence) end,
      "cursor_heavy" => fn -> Parser.parse(emulator, cursor_heavy) end,
      "large_text" => fn -> Parser.parse(emulator, large_text) end
    }, 
    time: 10,
    memory_time: 2,
    warmup: 2,
    formatters: [
      Benchee.Formatters.Console,
      {Benchee.Formatters.HTML, file: "bench/output/parser_benchmark.html"}
    ])
    
    profile_csi_parsing(emulator)
    profile_state_transitions(emulator)
  end
  
  defp profile_csi_parsing(emulator) do
    IO.puts("\nCSI Parsing Profile:")
    
    csi_sequences = [
      "\e[31m",     # SGR
      "\e[1;1H",    # CUP
      "\e[2J",      # ED
      "\e[K",       # EL
      "\e[10;20r",  # DECSTBM
      "\e[?25h",    # DECTCEM show
      "\e[?25l"     # DECTCEM hide
    ]
    
    results = Enum.map(csi_sequences, fn seq ->
      {time, _} = :timer.tc(fn ->
        Enum.each(1..10000, fn _ -> Parser.parse(emulator, seq) end)
      end)
      {seq, time / 10000}
    end)
    
    Enum.each(results, fn {seq, avg_μs} ->
      IO.puts("  #{inspect(seq)} => #{Float.round(avg_μs, 2)} μs")
    end)
  end
  
  defp profile_state_transitions(emulator) do
    IO.puts("\nState Transition Profile:")
    
    transitions = [
      {"ground->escape", "\e"},
      {"escape->csi", "\e["},
      {"csi->ground", "\e[31m"},
      {"ground->osc", "\e]"},
      {"osc->ground", "\e]0;Title\e\\"}
    ]
    
    results = Enum.map(transitions, fn {name, seq} ->
      {time, _} = :timer.tc(fn ->
        Enum.each(1..10000, fn _ -> Parser.parse(emulator, seq) end)
      end)
      {name, time / 10000}
    end)
    
    Enum.each(results, fn {transition, avg_μs} ->
      IO.puts("  #{transition} => #{Float.round(avg_μs, 2)} μs")
    end)
  end
end

ParserBenchmark.run()