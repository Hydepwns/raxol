defmodule Raxol.Terminal.Commands.CSIHandler.Screen do
  @moduledoc """
  Handles screen-related CSI sequences.
  """

  @doc """
  Handles screen commands.
  """
  @spec handle_command(term(), list(), String.t()) ::
          {:ok, term()} | {:error, term()}
  def handle_command(emulator, params, command) do
    case command do
      "J" -> handle_erase_display(emulator, params)
      "K" -> handle_erase_line(emulator, params)
      "S" -> handle_scroll_up(emulator, params)
      "T" -> handle_scroll_down(emulator, params)
      "@" -> handle_insert_characters(emulator, params)
      "P" -> handle_delete_characters(emulator, params)
      "L" -> handle_insert_lines(emulator, params)
      "M" -> handle_delete_lines(emulator, params)
      "X" -> handle_erase_characters(emulator, params)
      _ -> {:error, :unknown_screen_command}
    end
  end

  defp handle_erase_display(emulator, _params) do
    # Stub implementation
    {:ok, emulator}
  end

  defp handle_erase_line(emulator, _params) do
    # Stub implementation
    {:ok, emulator}
  end

  defp handle_scroll_up(emulator, _params) do
    # Stub implementation
    {:ok, emulator}
  end

  defp handle_scroll_down(emulator, _params) do
    # Stub implementation
    {:ok, emulator}
  end

  defp handle_insert_characters(emulator, params) do
    count = get_param(params, 0, 1)
    # Delegate to UnifiedCommandHandler for proper ICH implementation
    alias Raxol.Terminal.Commands.UnifiedCommandHandler

    case UnifiedCommandHandler.handle_csi(emulator, "@", [count]) do
      {:ok, updated_emulator} -> {:ok, updated_emulator}
      {:error, _, updated_emulator} -> {:ok, updated_emulator}
      updated_emulator -> {:ok, updated_emulator}
    end
  end

  defp handle_delete_characters(emulator, params) do
    count = get_param(params, 0, 1)
    alias Raxol.Terminal.Commands.UnifiedCommandHandler

    case UnifiedCommandHandler.handle_csi(emulator, "P", [count]) do
      {:ok, updated_emulator} -> {:ok, updated_emulator}
      {:error, _, updated_emulator} -> {:ok, updated_emulator}
      updated_emulator -> {:ok, updated_emulator}
    end
  end

  defp handle_insert_lines(emulator, params) do
    count = get_param(params, 0, 1)
    alias Raxol.Terminal.Commands.UnifiedCommandHandler

    case UnifiedCommandHandler.handle_csi(emulator, "L", [count]) do
      {:ok, updated_emulator} -> {:ok, updated_emulator}
      {:error, _, updated_emulator} -> {:ok, updated_emulator}
      updated_emulator -> {:ok, updated_emulator}
    end
  end

  defp handle_delete_lines(emulator, params) do
    count = get_param(params, 0, 1)
    alias Raxol.Terminal.Commands.UnifiedCommandHandler

    case UnifiedCommandHandler.handle_csi(emulator, "M", [count]) do
      {:ok, updated_emulator} -> {:ok, updated_emulator}
      {:error, _, updated_emulator} -> {:ok, updated_emulator}
      updated_emulator -> {:ok, updated_emulator}
    end
  end

  defp handle_erase_characters(emulator, params) do
    count = get_param(params, 0, 1)
    alias Raxol.Terminal.Commands.UnifiedCommandHandler

    case UnifiedCommandHandler.handle_csi(emulator, "X", [count]) do
      {:ok, updated_emulator} -> {:ok, updated_emulator}
      {:error, _, updated_emulator} -> {:ok, updated_emulator}
      updated_emulator -> {:ok, updated_emulator}
    end
  end

  defp get_param(params, index, default) do
    case Enum.at(params, index) do
      nil -> default
      val -> val
    end
  end
end
