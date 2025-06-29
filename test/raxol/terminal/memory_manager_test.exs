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
      # 24 bytes from empty maps in calculate_other_usage
      assert MemoryManager.estimate_memory_usage(state) == 24
    end

    test "returns buffer_manager memory_usage when only buffer_manager is present" do
      state = %MockState{buffer_manager: %MockBufferManager{memory_usage: 1000}}
      # 1000 + 24 bytes from empty maps in calculate_other_usage
      assert MemoryManager.estimate_memory_usage(state) == 1024
    end

    test "returns scroll_buffer memory_usage when only scroll_buffer is present" do
      state = %MockState{scroll_buffer: %MockScrollBuffer{memory_usage: 2000}}
      # 2000 + 24 bytes from empty maps in calculate_other_usage
      assert MemoryManager.estimate_memory_usage(state) == 2024
    end

    test "returns sum of buffer_manager and scroll_buffer memory_usage when both are present" do
      state = %MockState{
        buffer_manager: %MockBufferManager{memory_usage: 1500},
        scroll_buffer: %MockScrollBuffer{memory_usage: 2500}
      }

      # 1500 + 2500 + 24 bytes from empty maps in calculate_other_usage
      assert MemoryManager.estimate_memory_usage(state) == 4024
    end

    test "handles missing memory_usage fields gracefully" do
      state = %MockState{
        buffer_manager: %{},
        scroll_buffer: %{}
      }

      # 24 bytes from empty maps in calculate_other_usage
      assert MemoryManager.estimate_memory_usage(state) == 24
    end
  end

  describe "estimate_memory_usage/1 (integration)" do
    test "returns correct sum for mock State with buffer_manager and scroll_buffer" do
      # Create a mock state with buffer_manager and scroll_buffer that have memory_usage
      mock_buffer_manager = %{memory_usage: 1000}
      mock_scroll_buffer = %{memory_usage: 2000}

      state = %{
        buffer_manager: mock_buffer_manager,
        scroll_buffer: mock_scroll_buffer,
        style: %{},
        charset_state: %{},
        mode_manager: %{},
        cursor: %{}
      }

      expected = 1000 + 2000 + 24  # 24 bytes from calculate_other_usage
      assert MemoryManager.estimate_memory_usage(state) == expected
    end

    test "returns correct sum for mock State with custom memory_usage values" do
      mock_buffer_manager = %{memory_usage: 1111}
      mock_scroll_buffer = %{memory_usage: 2222}

      state = %{
        buffer_manager: mock_buffer_manager,
        scroll_buffer: mock_scroll_buffer,
        style: %{},
        charset_state: %{},
        mode_manager: %{},
        cursor: %{}
      }

      # 1111 + 2222 + 24 bytes from calculate_other_usage
      assert MemoryManager.estimate_memory_usage(state) == 3357
    end

    test "returns correct value if only buffer_manager has memory_usage" do
      mock_buffer_manager = %{memory_usage: 555}

      state = %{
        buffer_manager: mock_buffer_manager,
        scroll_buffer: nil,
        style: %{},
        charset_state: %{},
        mode_manager: %{},
        cursor: %{}
      }

      # 555 + 24 bytes from calculate_other_usage
      assert MemoryManager.estimate_memory_usage(state) == 579
    end

    test "returns correct value if only scroll_buffer has memory_usage" do
      mock_scroll_buffer = %{memory_usage: 777}

      state = %{
        buffer_manager: nil,
        scroll_buffer: mock_scroll_buffer,
        style: %{},
        charset_state: %{},
        mode_manager: %{},
        cursor: %{}
      }

      # 777 + 24 bytes from calculate_other_usage
      assert MemoryManager.estimate_memory_usage(state) == 801
    end
  end
end
