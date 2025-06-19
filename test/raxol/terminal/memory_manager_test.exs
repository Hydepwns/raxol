defmodule Raxol.Terminal.MemoryManagerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.MemoryManager

  defmodule MockBufferManager do
    defstruct memory_usage: 1234
  end

  defmodule MockScrollBuffer do
    defstruct memory_usage: 5678
  end

  defmodule MockState do
    defstruct buffer_manager: nil, scroll_buffer: nil
  end

  describe "estimate_memory_usage/1" do
    test "returns 0 when both buffer_manager and scroll_buffer are missing" do
      state = %MockState{}
      assert MemoryManager.estimate_memory_usage(state) == 0
    end

    test "returns buffer_manager memory_usage when only buffer_manager is present" do
      state = %MockState{buffer_manager: %MockBufferManager{memory_usage: 1000}}
      assert MemoryManager.estimate_memory_usage(state) == 1000
    end

    test "returns scroll_buffer memory_usage when only scroll_buffer is present" do
      state = %MockState{scroll_buffer: %MockScrollBuffer{memory_usage: 2000}}
      assert MemoryManager.estimate_memory_usage(state) == 2000
    end

    test "returns sum of buffer_manager and scroll_buffer memory_usage when both are present" do
      state = %MockState{
        buffer_manager: %MockBufferManager{memory_usage: 1500},
        scroll_buffer: %MockScrollBuffer{memory_usage: 2500}
      }

      assert MemoryManager.estimate_memory_usage(state) == 4000
    end

    test "handles missing memory_usage fields gracefully" do
      state = %MockState{
        buffer_manager: %{},
        scroll_buffer: %{}
      }

      assert MemoryManager.estimate_memory_usage(state) == 0
    end
  end

  describe "estimate_memory_usage/1 (integration)" do
    test "returns correct sum for real State with default config" do
      config = Raxol.Terminal.Config.Defaults.generate_default_config()

      behavior_keys =
        Raxol.Terminal.Config.Defaults.default_behavior_config() |> Map.keys()

      behavior = Map.take(config, behavior_keys)
      config = Map.put(config, :behavior, behavior)
      state = Raxol.Terminal.Integration.State.new(80, 24, config)

      # By default, both buffer_manager and scroll_buffer should have memory_usage fields
      expected =
        (state.buffer_manager.memory_usage || 0) +
          (state.scroll_buffer.memory_usage || 0)

      assert MemoryManager.estimate_memory_usage(state) == expected
    end

    test "returns correct sum for State with custom memory_usage values" do
      config = Raxol.Terminal.Config.Defaults.generate_default_config()

      behavior_keys =
        Raxol.Terminal.Config.Defaults.default_behavior_config() |> Map.keys()

      behavior = Map.take(config, behavior_keys)
      config = Map.put(config, :behavior, behavior)
      state = Raxol.Terminal.Integration.State.new(80, 24, config)
      # Manually set memory_usage fields
      buffer_manager = Map.put(state.buffer_manager, :memory_usage, 1111)
      scroll_buffer = Map.put(state.scroll_buffer, :memory_usage, 2222)

      state = %{
        state
        | buffer_manager: buffer_manager,
          scroll_buffer: scroll_buffer
      }

      assert MemoryManager.estimate_memory_usage(state) == 3333
    end

    test "returns correct value if only buffer_manager has memory_usage" do
      config = Raxol.Terminal.Config.Defaults.generate_default_config()

      behavior_keys =
        Raxol.Terminal.Config.Defaults.default_behavior_config() |> Map.keys()

      behavior = Map.take(config, behavior_keys)
      config = Map.put(config, :behavior, behavior)
      state = Raxol.Terminal.Integration.State.new(80, 24, config)
      buffer_manager = Map.put(state.buffer_manager, :memory_usage, 555)
      state = %{state | buffer_manager: buffer_manager, scroll_buffer: nil}
      assert MemoryManager.estimate_memory_usage(state) == 555
    end

    test "returns correct value if only scroll_buffer has memory_usage" do
      config = Raxol.Terminal.Config.Defaults.generate_default_config()

      behavior_keys =
        Raxol.Terminal.Config.Defaults.default_behavior_config() |> Map.keys()

      behavior = Map.take(config, behavior_keys)
      config = Map.put(config, :behavior, behavior)
      state = Raxol.Terminal.Integration.State.new(80, 24, config)
      scroll_buffer = Map.put(state.scroll_buffer, :memory_usage, 777)
      state = %{state | buffer_manager: nil, scroll_buffer: scroll_buffer}
      assert MemoryManager.estimate_memory_usage(state) == 777
    end
  end
end
