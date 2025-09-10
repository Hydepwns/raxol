defmodule Raxol.Web.SupervisorTest do
  use ExUnit.Case, async: false

  setup do
    # Ensure Phoenix.PubSub is started for the test
    if !Process.whereis(Raxol.PubSub) do
      {:ok, _pid} =
        Supervisor.start_link([{Phoenix.PubSub, name: Raxol.PubSub}],
          strategy: :one_for_one
        )
    end

    # Check if web supervisor is already running
    case Process.whereis(Raxol.Web.Supervisor) do
      nil ->
        # Start the web supervisor for testing with error handling
        case Raxol.Web.Supervisor.start_link([]) do
          {:ok, pid} ->
            {:ok, %{supervisor_pid: pid}}

          {:error, reason} ->
            flunk("Failed to start Web.Supervisor: #{inspect(reason)}")
        end

      pid when is_pid(pid) ->
        # Supervisor already running, use existing pid
        {:ok, %{supervisor_pid: pid}}
    end
  end

  test "is running and supervises expected children", %{supervisor_pid: pid} do
    assert is_pid(pid)
    assert Process.alive?(pid)

    # Get children with error handling
    children = Supervisor.which_children(pid)
    IO.puts("Web.Supervisor children: #{inspect(children)}")

    # Check that the supervisor has children
    assert length(children) > 0

    # Check for specific expected children
    child_modules = Enum.map(children, fn {mod, _, _, _} -> mod end)
    assert Raxol.Web.WebManager in child_modules
  end
end
