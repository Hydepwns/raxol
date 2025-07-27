defmodule Raxol.Plugins.Lifecycle.Validation do
  @moduledoc """
  Handles field and config validation helpers for plugin lifecycle management.
  """

  def validate_string_field(value, _field) when is_binary(value), do: :ok

  def validate_string_field(_value, field),
    do: {:error, {:invalid_field, field, :string}}

  def validate_boolean_field(value, _field) when is_boolean(value), do: :ok

  def validate_boolean_field(_value, field),
    do: {:error, {:invalid_field, field, :boolean}}

  def validate_map_field(value, _field) when is_map(value), do: :ok

  def validate_map_field(_value, field),
    do: {:error, {:invalid_field, field, :map}}
end
