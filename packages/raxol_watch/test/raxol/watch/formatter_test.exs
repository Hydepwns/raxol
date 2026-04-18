defmodule Raxol.Watch.FormatterTest do
  use ExUnit.Case, async: true

  alias Raxol.Watch.Formatter

  describe "format_announcement/2" do
    test "formats a simple announcement" do
      notif = Formatter.format_announcement("Server restarted")
      assert notif.title == "Raxol"
      assert notif.body == "Server restarted"
      assert notif.priority == :normal
      assert notif.badge == 0
      assert is_list(notif.actions)
    end

    test "maps high priority to high push priority with badge" do
      notif = Formatter.format_announcement("CRITICAL: Memory exhausted", :high)
      assert notif.priority == :high
      assert notif.badge == 1
    end

    test "maps low priority to silent push" do
      notif = Formatter.format_announcement("Background sync done", :low)
      assert notif.priority == :silent
    end

    test "high priority includes acknowledge action" do
      notif = Formatter.format_announcement("Alert!", :high)
      action_ids = Enum.map(notif.actions, & &1.id)
      assert "acknowledge" in action_ids
    end

    test "truncates long messages" do
      long = String.duplicate("x", 300)
      notif = Formatter.format_announcement(long)
      assert String.length(notif.body) <= Formatter.max_body_length()
      assert String.ends_with?(notif.body, "...")
    end

    test "does not truncate short messages" do
      notif = Formatter.format_announcement("Short")
      assert notif.body == "Short"
    end
  end

  describe "format_model_summary/2" do
    test "formats projections as multi-line body" do
      notif = Formatter.format_model_summary([
        {"Memory", "48 MB"},
        {"Processes", "412"},
        {"Status", "Healthy"}
      ])

      assert notif.body =~ "Memory: 48 MB"
      assert notif.body =~ "Processes: 412"
      assert notif.body =~ "Status: Healthy"
      assert notif.priority == :normal
      assert notif.category == "raxol_status"
    end

    test "accepts custom title" do
      notif = Formatter.format_model_summary("Dashboard", [{"CPU", "38%"}])
      assert notif.title == "Dashboard"
    end

    test "truncates long summaries" do
      projections = for i <- 1..50, do: {"Key #{i}", String.duplicate("v", 20)}
      notif = Formatter.format_model_summary(projections)
      assert String.length(notif.body) <= Formatter.max_body_length()
    end
  end
end
