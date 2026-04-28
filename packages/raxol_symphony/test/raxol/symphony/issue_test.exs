defmodule Raxol.Symphony.IssueTest do
  use ExUnit.Case, async: true

  alias Raxol.Symphony.Issue

  defp issue(state) do
    %Issue{id: "abc", identifier: "MT-1", title: "x", state: state}
  end

  describe "active?/2" do
    test "true when state matches case-insensitively" do
      assert Issue.active?(issue("In Progress"), ["Todo", "In Progress"])
      assert Issue.active?(issue("in progress"), ["Todo", "In Progress"])
      assert Issue.active?(issue("TODO"), ["Todo", "In Progress"])
    end

    test "false when state is not in the active list" do
      refute Issue.active?(issue("Done"), ["Todo", "In Progress"])
      refute Issue.active?(issue(""), ["Todo", "In Progress"])
    end
  end

  describe "terminal?/2" do
    test "true when state matches case-insensitively" do
      assert Issue.terminal?(issue("Done"), ["Done", "Cancelled"])
      assert Issue.terminal?(issue("CANCELLED"), ["Done", "Cancelled"])
    end

    test "false when state is not in the terminal list" do
      refute Issue.terminal?(issue("In Progress"), ["Done", "Cancelled"])
    end
  end

  describe "struct enforcement" do
    test "requires id, identifier, title, state" do
      assert_raise ArgumentError, fn ->
        struct!(Issue, identifier: "MT-1", title: "x", state: "Todo")
      end
    end

    test "default fields are populated" do
      issue = %Issue{id: "a", identifier: "MT-1", title: "x", state: "Todo"}
      assert issue.labels == []
      assert issue.blocked_by == []
      assert issue.priority == nil
      assert issue.description == nil
    end
  end
end
