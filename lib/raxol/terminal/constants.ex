defmodule Raxol.Terminal.Constants do
  @moduledoc """
  Re-exports constants from ExTermbox.Constants for use within Raxol.

  This module serves as a compatibility layer and convenience wrapper around
  the ExTermbox.Constants module.
  """

  @doc """
  Gets attribute value by name.

  ## Examples

      iex> Constants.attribute(:bold)
      0x0100
      iex> Constants.attribute(:underline)
      0x0200
  """
  @spec attribute(atom()) :: 256 | 512 | 1024
  def attribute(name), do: ExTermbox.Constants.attribute(name)

  @doc """
  Gets color value by name.

  ## Examples

      iex> Constants.color(:red)
      0x02
      iex> Constants.color(:blue)
      0x05
  """
  @spec color(atom()) :: 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8
  def color(name), do: ExTermbox.Constants.color(name)

  @doc """
  Gets key value by name.

  ## Examples

      iex> Constants.key(:esc)
      0x1B
      iex> Constants.key(:space)
      0x20
  """
  @spec key(atom()) :: char()
  def key(name), do: ExTermbox.Constants.key(name)

  @doc """
  Gets event type value by name.

  ## Examples

      iex> Constants.event_type(:key)
      0x01
  """
  @spec event_type(atom()) :: 1 | 2 | 3
  def event_type(name), do: ExTermbox.Constants.event_type(name)
end
