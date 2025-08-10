defmodule Raxol.Test.DockerHelper do
  @moduledoc """
  Helper module for handling Docker availability in tests.

  Provides utilities to check if Docker is available and skip
  Docker-dependent tests when running in environments without Docker
  (like macOS CI runners).
  """

  @doc """
  Check if Docker is available in the current environment.

  Returns true if Docker is installed and accessible, false otherwise.
  """
  def docker_available? do
    case System.cmd("docker", ["version"], stderr_to_stdout: true) do
      {_output, 0} ->
        # Docker command succeeded
        true

      _ ->
        # Docker not available or command failed
        false
    end
  rescue
    _ -> false
  end

  @doc """
  Skip test if Docker is not available.

  Use this in test setup or as a tag:

      @tag :requires_docker
      test "something that needs Docker" do
        skip_unless_docker_available()
        # ... test code ...
      end
  """
  def skip_unless_docker_available do
    unless docker_available?() do
      skip_test("Docker is not available in this environment")
    end
  end

  @doc """
  Skip test if running on macOS CI without Docker.
  """
  def skip_on_macos_ci do
    if macos_ci_without_docker?() do
      skip_test("Skipping on macOS CI (Docker not available)")
    end
  end

  @doc """
  Check if running on macOS CI without Docker.
  """
  def macos_ci_without_docker? do
    System.get_env("CI") == "true" and
      System.get_env("RUNNER_OS") == "macOS" and
      not docker_available?()
  end

  @doc """
  Get Docker status message for debugging.
  """
  def docker_status do
    cond do
      docker_available?() ->
        "Docker is available"

      System.get_env("CI") == "true" ->
        "Docker not available in CI environment"

      true ->
        "Docker not available locally"
    end
  end

  defp skip_test(reason) do
    # Use ExUnit's skip macro through raising SkipError
    raise ExUnit.SkipError, message: reason
  end

  @doc """
  Conditionally run code based on Docker availability.

  ## Examples

      with_docker do
        # This code only runs if Docker is available
        container_id = start_test_container()
        # ...
      end
  """
  defmacro with_docker(do: block) do
    quote do
      if Raxol.Test.DockerHelper.docker_available?() do
        unquote(block)
      else
        :skipped
      end
    end
  end

  @doc """
  Alternative implementation for when Docker is not available.

  ## Examples

      test "database test" do
        result = without_docker do
          # Use mock database
          Raxol.Test.MockDB.query("SELECT 1")
        else
          # Use real PostgreSQL in Docker
          run_in_docker_postgres("SELECT 1")
        end
        
        assert result == [1]
      end
  """
  defmacro without_docker(do: no_docker_block, else: docker_block) do
    quote do
      if Raxol.Test.DockerHelper.docker_available?() do
        unquote(docker_block)
      else
        unquote(no_docker_block)
      end
    end
  end
end
