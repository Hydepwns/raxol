defmodule Raxol.Web.SupervisorTest do
  use ExUnit.Case, async: false

  setup do
    # Start the web supervisor for testing
    {:ok, pid} = Raxol.Web.Supervisor.start_link([])
    {:ok, %{supervisor_pid: pid}}
  end

  test "is running and supervises expected children", %{supervisor_pid: pid} do
    assert is_pid(pid)
    assert Process.alive?(pid)
    children = Supervisor.which_children(pid)

    assert Enum.any?(children, fn {mod, _, _, _} -> mod == Raxol.Web.Manager end)
  end
end
