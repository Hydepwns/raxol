defmodule Raxol.Terminal.Commands.BufferHandler do
  @moduledoc """
  @deprecated "Use Raxol.Terminal.Commands.UnifiedCommandHandler instead"

  This module has been consolidated into the unified command handling system.
  For new code, use:

      # Instead of BufferHandler.handle_L(emulator, count)
      UnifiedCommandHandler.handle_csi(emulator, "L", [count])
      
      # Instead of BufferHandler.handle_M(emulator, count)  
      UnifiedCommandHandler.handle_csi(emulator, "M", [count])
      
      # Instead of BufferHandler.handle_P(emulator, count)
      UnifiedCommandHandler.handle_csi(emulator, "P", [count])
      
      # Instead of BufferHandler.handle_at(emulator, count)
      UnifiedCommandHandler.handle_csi(emulator, "@", [count])
  """

  alias Raxol.Terminal.Commands.UnifiedCommandHandler
  require Raxol.Core.Runtime.Log

  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_l(emulator, count) do
    IO.puts(
      :stderr,
      "Warning: BufferHandler.handle_l/2 is deprecated. Use UnifiedCommandHandler instead."
    )

    UnifiedCommandHandler.handle_csi(emulator, "L", normalize_count(count))
  end

  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_m(emulator, count) do
    IO.puts(
      :stderr,
      "Warning: BufferHandler.handle_m/2 is deprecated. Use UnifiedCommandHandler instead."
    )

    UnifiedCommandHandler.handle_csi(emulator, "M", normalize_count(count))
  end

  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_x(emulator, count) do
    IO.puts(
      :stderr,
      "Warning: BufferHandler.handle_x/2 is deprecated. Use UnifiedCommandHandler instead."
    )

    UnifiedCommandHandler.handle_csi(emulator, "X", normalize_count(count))
  end

  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_l_alias(emulator, count) do
    IO.puts(
      :stderr,
      "Warning: BufferHandler.handle_l_alias/2 is deprecated. Use UnifiedCommandHandler instead."
    )

    UnifiedCommandHandler.handle_csi(emulator, "L", normalize_count(count))
  end

  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_m_alias(emulator, count) do
    IO.puts(
      :stderr,
      "Warning: BufferHandler.handle_m_alias/2 is deprecated. Use UnifiedCommandHandler instead."
    )

    UnifiedCommandHandler.handle_csi(emulator, "M", normalize_count(count))
  end

  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_p_alias(emulator, count) do
    IO.puts(
      :stderr,
      "Warning: BufferHandler.handle_p_alias/2 is deprecated. Use UnifiedCommandHandler instead."
    )

    UnifiedCommandHandler.handle_csi(emulator, "P", normalize_count(count))
  end

  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_x_alias(emulator, count) do
    IO.puts(
      :stderr,
      "Warning: BufferHandler.handle_x_alias/2 is deprecated. Use UnifiedCommandHandler instead."
    )

    UnifiedCommandHandler.handle_csi(emulator, "X", normalize_count(count))
  end

  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_at(emulator, count) do
    IO.puts(
      :stderr,
      "Warning: BufferHandler.handle_at/2 is deprecated. Use UnifiedCommandHandler instead."
    )

    UnifiedCommandHandler.handle_csi(emulator, "@", normalize_count(count))
  end

  # Uppercase aliases
  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_L(emulator, count), do: handle_l_alias(emulator, count)

  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_M(emulator, count), do: handle_m_alias(emulator, count)

  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_P(emulator, count), do: handle_p_alias(emulator, count)

  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_X(emulator, count), do: handle_x_alias(emulator, count)

  # Helper function to normalize count parameter
  defp normalize_count(count) do
    case count do
      [n] when is_integer(n) -> [n]
      n when is_integer(n) -> [n]
      _ -> [1]
    end
  end
end
