defmodule Raxol.Terminal.Extension.Custom do
  @moduledoc """
  A test custom extension for the Raxol terminal emulator.
  """

  def get_custom_info do
    %{
      name: "Test Custom",
      version: "1.0.0",
      description: "A test custom extension",
      author: "Test Author",
      license: "MIT",
      features: ["feature1", "feature2", "feature3"]
    }
  end

  def execute_feature("feature1", args) do
    # Execute feature1
    {:ok, "Feature1 executed with args: #{inspect(args)}"}
  end

  def execute_feature("feature2", args) do
    # Execute feature2
    {:ok, "Feature2 executed with args: #{inspect(args)}"}
  end

  def execute_feature("feature3", args) do
    # Execute feature3
    {:ok, "Feature3 executed with args: #{inspect(args)}"}
  end

  def execute_feature(feature, _args) do
    {:error, :feature_not_found, "Feature '#{feature}' not found"}
  end

  def get_custom_state do
    # Return current custom extension state
    {:ok,
     %{
       status: "idle",
       active_features: [],
       last_error: nil,
       start_time: nil,
       end_time: nil
     }}
  end

  def update_custom_config(config) do
    # Update custom extension configuration
    {:ok, config}
  end

  def register_callback(event, callback) do
    # Register callback for event
    {:ok, %{event: event, callback: callback}}
  end

  def unregister_callback(event, _callback) do
    # Unregister callback for event
    :ok
  end

  def trigger_event(event, args) do
    # Trigger event with args
    {:ok, args}
  end
end
