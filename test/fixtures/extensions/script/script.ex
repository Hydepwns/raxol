defmodule Raxol.Terminal.Extension.Script do
  @moduledoc '''
  A test script extension for the Raxol terminal emulator.
  '''

  def get_script_info do
    %{
      name: "Test Script",
      version: "1.0.0",
      description: "A test script extension",
      author: "Test Author",
      license: "MIT",
      commands: ["run", "stop", "status"]
    }
  end

  def execute_command("run", args) do
    # Simulate running a script
    {:ok, "Command "run" executed with args: #{inspect(args)}"}
  end

  def execute_command("stop", _args) do
    # Simulate stopping a script
    {:ok, "Command "stop" executed"}
  end

  def execute_command("status", _args) do
    # Simulate getting script status
    {:ok,
     %{
       status: "running",
       uptime: 3600,
       memory_usage: "10MB",
       cpu_usage: "5%"
     }}
  end

  def execute_command(command, _args) do
    {:error, :command_not_found, "Command "#{command}" not found"}
  end

  def get_script_state do
    # Return current script state
    {:ok,
     %{
       status: "idle",
       last_command: nil,
       last_error: nil,
       start_time: nil,
       end_time: nil
     }}
  end

  def update_script_config(config) do
    # Update script configuration
    {:ok, config}
  end
end
