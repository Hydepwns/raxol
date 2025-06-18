defmodule Raxol.Terminal.Plugin.Extension do
  @moduledoc '''
  Test extension plugin for the Raxol terminal emulator.
  '''

  def run_extension(extension_name, args \\ []) do
    # Default extension configuration
    default_config = %{
      enabled: true,
      priority: 1,
      hooks: [:init, :update, :cleanup]
    }

    # Get extension configuration
    config = get_extension_config(extension_name)
    config = Map.merge(default_config, config)

    # Run extension
    case execute_extension(extension_name, args, config) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_extension_info do
    %{
      name: "Test Extension",
      version: "1.0.0",
      description: "A test extension for the Raxol terminal emulator",
      author: "Test Author",
      license: "MIT",
      extensions: [
        "test_extension",
        "another_extension"
      ]
    }
  end

  # Private Functions
  defp get_extension_config(extension_name) do
    # In a real implementation, this would load configuration from a file
    %{
      "test_extension" => %{
        enabled: true,
        priority: 1,
        hooks: [:init, :update]
      },
      "another_extension" => %{
        enabled: true,
        priority: 2,
        hooks: [:init, :cleanup]
      }
    }
    |> Map.get(extension_name, %{})
  end

  defp execute_extension(extension_name, args, config) do
    # In a real implementation, this would execute the actual extension
    case extension_name do
      "test_extension" ->
        {:ok,
         %{
           extension: extension_name,
           args: args,
           config: config,
           result: "Test extension executed successfully"
         }}

      "another_extension" ->
        {:ok,
         %{
           extension: extension_name,
           args: args,
           config: config,
           result: "Another extension executed successfully"
         }}

      _ ->
        {:error, :extension_not_found}
    end
  end
end
