defmodule Raxol.Web.SupervisorTest do
  use ExUnit.Case, async: true

  test "is running and supervises expected children" do
    pid = Process.whereis(Raxol.Web.Supervisor)
    assert is_pid(pid)
    assert Process.alive?(pid)
    children = Supervisor.which_children(pid)
    assert Enum.any?(children, fn {mod, _, _, _} -> mod == Raxol.Web.Manager end)
  end
end
