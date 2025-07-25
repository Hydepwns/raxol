defmodule Raxol.Core.Metrics.AlertManagerTest do
  @moduledoc """
  Tests for the alert manager, including rule management, alert evaluation,
  acknowledgment, grouped metrics, and error handling.
  """
  use ExUnit.Case, async: true
  alias Raxol.Core.Metrics.AlertManager

  setup do
    # Start UnifiedCollector for metrics dependency
    {:ok, _uc_pid} = Raxol.Core.Metrics.UnifiedCollector.start_link()

    # Use a unique name for each test to avoid conflicts
    test_name = String.to_atom("alert_manager_test_#{:rand.uniform(1_000_000)}")
    {:ok, pid} = AlertManager.start_link(name: test_name)

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    {:ok, test_name: test_name, pid: pid}
  end

  describe "rule management" do
    test "adds a new alert rule", %{test_name: test_name} do
      rule = %{
        name: "High CPU Usage",
        description: "Alert when CPU usage is above 80%",
        metric_name: "cpu_usage",
        condition: :above,
        threshold: 80,
        severity: :warning,
        tags: %{service: "test"},
        group_by: ["service"],
        cooldown: 300,
        notification_channels: ["email"]
      }

      assert {:ok, rule_id} = AlertManager.add_rule(rule, test_name)
      assert {:ok, rules} = AlertManager.get_rules(test_name)
      assert Map.has_key?(rules, rule_id)
    end

    test "validates and normalizes rule fields", %{test_name: test_name} do
      rule = %{
        metric_name: "test_metric",
        threshold: 50
      }

      assert {:ok, rule_id} = AlertManager.add_rule(rule, test_name)
      assert {:ok, rules} = AlertManager.get_rules(test_name)
      stored_rule = rules[rule_id]

      assert stored_rule.name == "Unnamed Alert"
      assert stored_rule.condition == :above
      assert stored_rule.severity == :warning
      assert stored_rule.tags == %{}
      assert stored_rule.group_by == []
      assert stored_rule.cooldown == 300
      assert stored_rule.notification_channels == []
    end
  end

  describe "alert evaluation" do
    setup %{test_name: test_name} do
      rule = %{
        name: "Test Alert",
        metric_name: "test_metric",
        condition: :above,
        threshold: 50,
        severity: :warning,
        tags: %{service: "test"}
      }

      {:ok, rule_id} = AlertManager.add_rule(rule, test_name)
      %{rule_id: rule_id}
    end

    test "triggers alert when condition is met", %{
      rule_id: rule_id,
      test_name: test_name,
      pid: pid
    } do
      metrics = [
        %{
          timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
          value: 60,
          tags: %{service: "test"}
        }
      ]

      try do
        # Cleanup - meck removed
      catch
        :error, {:not_mocked, _} -> :ok
      end

      # Note: UnifiedCollector started in setup, using real metrics instead of mocks

      # Force alert check only if process is alive
      if Process.alive?(pid) do
        Process.send(test_name, {:check_alerts, 1}, [])
        # Wait for alert to be processed
        Process.sleep(100)
      end

      assert {:ok, alert_state} =
               AlertManager.get_alert_state(rule_id, test_name)

      assert alert_state.active == true
      assert alert_state.current_value == 60

      # Cleanup - meck removed
    end

    test "does not trigger alert when condition is not met", %{
      rule_id: rule_id,
      test_name: test_name,
      pid: pid
    } do
      metrics = [
        %{
          timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
          value: 40,
          tags: %{service: "test"}
        }
      ]

      try do
        # Cleanup - meck removed
      catch
        :error, {:not_mocked, _} -> :ok
      end

      # Note: UnifiedCollector started in setup, using real metrics instead of mocks

      # Force alert check only if process is alive
      if Process.alive?(pid) do
        Process.send(test_name, {:check_alerts, 1}, [])
        # Wait for alert to be processed
        Process.sleep(100)
      end

      assert {:ok, alert_state} =
               AlertManager.get_alert_state(rule_id, test_name)

      assert alert_state.active == false
      assert alert_state.current_value == 40

      # Cleanup - meck removed
    end

    test "respects cooldown period", %{
      rule_id: rule_id,
      test_name: test_name,
      pid: pid
    } do
      metrics = [
        %{
          timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
          value: 60,
          tags: %{service: "test"}
        }
      ]

      try do
        # Cleanup - meck removed
      catch
        :error, {:not_mocked, _} -> :ok
      end

      # Note: UnifiedCollector started in setup, using real metrics instead of mocks

      # Force first alert check only if process is alive
      if Process.alive?(pid) do
        Process.send(test_name, {:check_alerts, 1}, [])
        Process.sleep(100)

        # Force second alert check immediately
        Process.send(test_name, {:check_alerts, 2}, [])
        Process.sleep(100)
      end

      assert {:ok, alert_state} =
               AlertManager.get_alert_state(rule_id, test_name)

      assert alert_state.active == false

      # Check alert history
      assert {:ok, history} =
               AlertManager.get_alert_history(rule_id, test_name)

      # Only one alert should be recorded due to cooldown
      assert length(history) == 1

      # Cleanup - meck removed
    end
  end

  describe "alert acknowledgment" do
    setup %{test_name: test_name} do
      rule = %{
        name: "Test Alert",
        metric_name: "test_metric",
        condition: :above,
        threshold: 50,
        severity: :warning,
        tags: %{service: "test"}
      }

      {:ok, rule_id} = AlertManager.add_rule(rule, test_name)
      %{rule_id: rule_id}
    end

    test "acknowledges an active alert", %{
      rule_id: rule_id,
      test_name: test_name,
      pid: pid
    } do
      metrics = [
        %{
          timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
          value: 60,
          tags: %{service: "test"}
        }
      ]

      try do
        # Cleanup - meck removed
      catch
        :error, {:not_mocked, _} -> :ok
      end

      # Note: UnifiedCollector started in setup, using real metrics instead of mocks

      # Force alert check only if process is alive
      if Process.alive?(pid) do
        Process.send(test_name, {:check_alerts, 1}, [])
        Process.sleep(100)
      end

      # Acknowledge alert
      assert {:ok, alert_state} =
               AlertManager.acknowledge_alert(rule_id, test_name)

      assert alert_state.acknowledged == true

      # Cleanup - meck removed
    end
  end

  describe "grouped metrics" do
    test "evaluates alerts for grouped metrics", %{
      test_name: test_name,
      pid: pid
    } do
      rule = %{
        name: "Grouped Alert",
        metric_name: "test_metric",
        condition: :above,
        threshold: 50,
        severity: :warning,
        tags: %{service: "test"},
        group_by: ["service", "region"]
      }

      {:ok, rule_id} = AlertManager.add_rule(rule, test_name)

      metrics = [
        %{
          timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
          value: 60,
          tags: %{service: "test", region: "us"}
        },
        %{
          timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
          value: 40,
          tags: %{service: "test", region: "eu"}
        }
      ]

      try do
        # Cleanup - meck removed
      catch
        :error, {:not_mocked, _} -> :ok
      end

      # Note: UnifiedCollector started in setup, using real metrics instead of mocks

      # Force alert check only if process is alive
      if Process.alive?(pid) do
        Process.send(test_name, {:check_alerts, 1}, [])
        Process.sleep(100)
      end

      assert {:ok, alert_state} =
               AlertManager.get_alert_state(rule_id, test_name)

      assert alert_state.active == true

      # Cleanup - meck removed
    end
  end

  describe "error handling" do
    test "returns error for non-existent rule", %{test_name: test_name} do
      assert {:error, :rule_not_found} =
               AlertManager.get_alert_state(999, test_name)

      assert {:error, :rule_not_found} =
               AlertManager.get_alert_history(999, test_name)

      assert {:error, :rule_not_found} =
               AlertManager.acknowledge_alert(999, test_name)

      assert {:ok, %{}} = AlertManager.get_rules(test_name)
    end
  end
end
