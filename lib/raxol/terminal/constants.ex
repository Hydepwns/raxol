defmodule Raxol.Terminal.Constants do
  @moduledoc """
  Re-exports constants from ExTermbox NIF v2.0.1 for use within Raxol.

  This module provides a convenience wrapper around the constant values
  defined in the ExTermbox module.
  """

  alias ExTermbox.Constants, as: TermboxConstants

  @doc "Returns the numeric value for the given color name"
  def color(name), do: TermboxConstants.color(name)

  @doc "Returns the numeric value for the given attribute name"
  def attribute(name), do: TermboxConstants.attribute(name)

  @doc "Returns the numeric value for the given key name"
  def key(name), do: TermboxConstants.key(name)

  @doc "Returns the numeric value for the given event type"
  def event_type(name), do: TermboxConstants.event_type(name)
end
