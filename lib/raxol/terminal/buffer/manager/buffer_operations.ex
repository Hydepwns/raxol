defmodule Raxol.Terminal.Buffer.Manager.BufferOperations do
  @moduledoc """
  Handles buffer operations for buffer managers.
  Extracted from Raxol.Terminal.Buffer.Manager to improve maintainability.
  """

  @doc """
  Resets a buffer manager to initial state.
  """

  # TODO: TestBufferManager struct needs to be defined or this clause removed
  # def reset_buffer_manager(
  #       %Raxol.Terminal.Buffer.Manager.TestBufferManager{} = mgr
  #     ) do
  #   %Raxol.Terminal.Buffer.Manager.TestBufferManager{
  #     scrollback_size: mgr.scrollback_size,
  #     active: nil,
  #     alternate: nil,
  #     scrollback: []
  #   }
  # end

  def reset_buffer_manager(%{buffer: _} = emulator) do
    %{emulator | buffer: Raxol.Terminal.Buffer.Manager.new()}
  end

  def reset_buffer_manager(%{active: _} = emulator) do
    %{
      emulator
      | active: nil,
        alternate: nil,
        scrollback: [],
        scrollback_size: 1000
    }
  end

  def reset_buffer_manager(emulator) when is_map(emulator) do
    emulator
    |> Map.put(:active, nil)
    |> Map.put(:alternate, nil)
    |> Map.put(:scrollback, [])
    |> Map.put(:scrollback_size, 1000)
  end

  def reset_buffer_manager(_manager) do
    Raxol.Terminal.Buffer.Manager.new()
  end

  @doc """
  Gets the active buffer.
  """

  # TODO: TestBufferManager struct needs to be defined
  # def get_screen_buffer(%Raxol.Terminal.Buffer.Manager.TestBufferManager{
  #       active: active
  #     }),
  #     do: active

  def get_screen_buffer(%{active: active}), do: active

  def get_screen_buffer(%Raxol.Terminal.Emulator{} = emulator) do
    emulator.active
  end

  def get_screen_buffer(pid) when is_pid(pid) or is_atom(pid),
    do: GenServer.call(pid, :get_screen_buffer)

  @doc """
  Gets the alternate buffer.
  """

  # TODO: TestBufferManager struct needs to be defined
  # def get_alternate_buffer(%Raxol.Terminal.Buffer.Manager.TestBufferManager{
  #       alternate: alternate
  #     }),
  #     do: alternate

  def get_alternate_buffer(%{alternate: alternate}), do: alternate

  # Legacy type-specific implementation removed - using pattern matching instead

  def get_alternate_buffer(%Raxol.Terminal.Emulator{} = emulator) do
    emulator.alternate
  end

  def get_alternate_buffer(emulator) when is_map(emulator),
    do: Map.get(emulator, :alternate, nil)

  @doc """
  Switches between active and alternate buffers.
  """

  # TODO: TestBufferManager struct needs to be defined
  # def switch_buffers(
  #       %Raxol.Terminal.Buffer.Manager.TestBufferManager{
  #         active: a,
  #         alternate: b
  #       } = mgr
  #     ),
  #     do: %{mgr | active: b, alternate: a}

  def switch_buffers(%Raxol.Terminal.Emulator{} = emulator) do
    %{emulator | active: emulator.alternate, alternate: emulator.active}
  end

  def switch_buffers(%{active: active, alternate: alternate} = emulator),
    do: %{emulator | active: alternate, alternate: active}

  @doc """
  Sets the active buffer.
  """

  # TODO: TestBufferManager struct needs to be defined
  # def set_active_buffer(
  #       %Raxol.Terminal.Buffer.Manager.TestBufferManager{} = mgr,
  #       buffer
  #     ),
  #     do: %{mgr | active: buffer}

  def set_active_buffer(nil, buffer),
    do: Raxol.Terminal.Buffer.Manager.new() |> set_active_buffer(buffer)

  # Legacy type-specific implementation removed - using pattern matching instead

  def set_active_buffer(%Raxol.Terminal.Emulator{} = emulator, buffer) do
    %{emulator | active: buffer}
  end

  def set_active_buffer(%{active: _} = emulator, buffer),
    do: %{emulator | active: buffer}

  def set_active_buffer(emulator, buffer) when is_map(emulator),
    do: Map.put(emulator, :active, buffer)

  @doc """
  Sets the alternate buffer.
  """

  # TODO: TestBufferManager struct needs to be defined
  # def set_alternate_buffer(
  #       %Raxol.Terminal.Buffer.Manager.TestBufferManager{} = mgr,
  #       buffer
  #     ),
  #     do: %{mgr | alternate: buffer}

  def set_alternate_buffer(nil, buffer),
    do: Raxol.Terminal.Buffer.Manager.new() |> set_alternate_buffer(buffer)

  # Legacy type-specific implementation removed - using pattern matching instead

  def set_alternate_buffer(%Raxol.Terminal.Emulator{} = emulator, buffer) do
    %{emulator | alternate: buffer}
  end

  def set_alternate_buffer(%{alternate: _} = emulator, buffer),
    do: %{emulator | alternate: buffer}

  def set_alternate_buffer(emulator, buffer) when is_map(emulator),
    do: Map.put(emulator, :alternate, buffer)
end
