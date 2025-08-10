defmodule Raxol.MinimalTest do
  use ExUnit.Case
  doctest Raxol.Minimal

  describe "minimal terminal startup" do
    test "starts with default options" do
      {:ok, pid} = Raxol.Minimal.start_terminal()
      state = Raxol.Minimal.get_state(pid)
      
      assert state.width == 80
      assert state.height == 24
      assert state.mode == :raw
      assert state.cursor == {0, 0}
      assert state.buffer == %{}
      
      GenServer.stop(pid)
    end
    
    test "starts with custom options" do
      {:ok, pid} = Raxol.Minimal.start_terminal(width: 120, height: 30, mode: :cooked)
      state = Raxol.Minimal.get_state(pid)
      
      assert state.width == 120
      assert state.height == 30
      assert state.mode == :cooked
      
      GenServer.stop(pid)
    end
    
    test "measures startup time" do
      start_time = System.monotonic_time(:millisecond)
      {:ok, pid} = Raxol.Minimal.start_terminal()
      end_time = System.monotonic_time(:millisecond)
      
      startup_time = end_time - start_time
      assert startup_time < 10, "Startup time should be under 10ms, got #{startup_time}ms"
      
      GenServer.stop(pid)
    end
  end
  
  describe "input handling" do
    setup do
      {:ok, pid} = Raxol.Minimal.start_terminal()
      %{terminal: pid}
    end
    
    test "processes cursor movement", %{terminal: pid} do
      # Move cursor right
      Raxol.Minimal.send_input(pid, "\e[C")
      Process.sleep(1)
      state = Raxol.Minimal.get_state(pid)
      assert state.cursor == {1, 0}
      
      # Move cursor down
      Raxol.Minimal.send_input(pid, "\e[B") 
      Process.sleep(1)
      state = Raxol.Minimal.get_state(pid)
      assert state.cursor == {1, 1}
      
      GenServer.stop(pid)
    end
    
    test "processes printable characters", %{terminal: pid} do
      Raxol.Minimal.send_input(pid, "A")
      Process.sleep(1)
      state = Raxol.Minimal.get_state(pid)
      
      assert Map.get(state.buffer, {0, 0}) == "A"
      assert state.cursor == {1, 0}
      
      GenServer.stop(pid)
    end
    
    test "respects terminal boundaries", %{terminal: pid} do
      # Try to move cursor beyond left boundary
      Raxol.Minimal.send_input(pid, "\e[D")
      Process.sleep(1)
      state = Raxol.Minimal.get_state(pid)
      assert state.cursor == {0, 0}
      
      GenServer.stop(pid)
    end
  end
end