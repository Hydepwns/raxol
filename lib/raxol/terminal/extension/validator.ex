defmodule Raxol.Terminal.Extension.Validator do
  @moduledoc """
  Handles extension validation operations including validating extensions and their components.
  """

  @doc """
  Validates an extension.
  """
  def validate_extension(extension) do
    with :ok <- validate_extension_type(extension.type),
         :ok <- validate_extension_config(extension.config),
         :ok <- validate_extension_dependencies(extension.dependencies) do
      validate_extension_module(extension.module)
    end
  end

  # Private functions

  defp validate_extension_type(type)
       when type in [:theme, :script, :plugin, :custom],
       do: :ok

  defp validate_extension_type(_), do: {:error, :invalid_extension_type}

  defp validate_extension_config(config) when is_map(config), do: :ok
  defp validate_extension_config(_), do: {:error, :invalid_extension_config}

  defp validate_extension_dependencies(dependencies) when is_list(dependencies),
    do: :ok

  defp validate_extension_dependencies(_),
    do: {:error, :invalid_extension_dependencies}

  defp validate_extension_module({:ok, _module}), do: :ok
  # Allow extensions without modules
  defp validate_extension_module({:error, _reason}), do: :ok
  defp validate_extension_module(nil), do: :ok
  defp validate_extension_module(_), do: {:error, :invalid_extension_module}
end
