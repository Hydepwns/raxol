defmodule Raxol.Core.Platform do
  @moduledoc """
  Platform detection utilities for cross-platform compatibility.
  """

  @doc """
  Checks if the current platform is macOS.
  """
  def macos? do
    case :os.type() do
      {:unix, :darwin} -> true
      _ -> false
    end
  end

  @doc """
  Checks if the current platform is Linux.
  """
  def linux? do
    case :os.type() do
      {:unix, :linux} -> true
      _ -> false
    end
  end

  @doc """
  Checks if the current platform is Windows.
  """
  def windows? do
    case :os.type() do
      {:win32, _} -> true
      _ -> false
    end
  end

  @doc """
  Returns the OS type as an atom.
  """
  def os_type do
    case :os.type() do
      {:unix, :darwin} -> :macos
      {:unix, :linux} -> :linux
      {:win32, _} -> :windows
      other -> other
    end
  end
end