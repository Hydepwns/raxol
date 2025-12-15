defmodule Raxol.Core.Metrics.AlertManagerTest do
  @moduledoc """
  Tests for the alert manager, including rule management, alert evaluation,
  acknowledgment, grouped metrics, and error handling.
  """
  use ExUnit.Case, async: false
  alias Raxol.Core.Metrics.AlertManager

  setup do
    # Start MetricsCollector for metrics dependency if not already started
    # MetricsCollector uses BaseManager and requires a name parameter
    uc_pid =
      case Raxol.Core.Metrics.MetricsCollector.start_link(
             name: Raxol.Core.Metrics.MetricsCollector
           ) do
        {:ok, pid} ->
          pid

        {:error, {:already_started, pid}} ->
          pid

        {:error, reason} ->
          raise "Failed to start MetricsCollector: #{inspect(reason)}"
      end

    # Clear any persisted ETS data from previous runs
    Raxol.Core.Metrics.MetricsCollector.clear_metrics()

    # Use a unique name for each test to avoid conflicts
    test_name = String.to_atom("alert_manager_test_#{:rand.uniform(1_000_000)}")
    {:ok, pid} = AlertManager.start_link(name: test_name)

    on_exit(fn ->
      try do
        if Process.alive?(pid) do
          GenServer.stop(pid, :normal, 1000)
        end
      catch
        # Process already dead
        :exit, {:noproc, _} -> :ok
        # Timeout is acceptable in cleanup
        :exit, {:timeout, _} -> :ok
      end

      # Also stop MetricsCollector if we started it
      try do
        if uc_pid && Process.alive?(uc_pid) do
          GenServer.stop(uc_pid, :normal, 1000)
        end
      catch
        # Process already dead
        :exit, {:noproc, _} -> :ok
        # Timeout is acceptable in cleanup
        :exit, {:timeout, _} -> :ok
      end
    end)

    {:ok, test_name: test_name, pid: pid, collector_pid: uc_pid}
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
      # Record metrics into MetricsCollector
      Raxol.Core.Metrics.MetricsCollector.record_metric(
        "test_metric",
        :custom,
        60,
        tags: %{service: "test"}
      )

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
    end

    test "does not trigger alert when condition is not met", %{
      rule_id: rule_id,
      test_name: test_name,
      pid: pid
    } do
      # Record metrics into MetricsCollector
      Raxol.Core.Metrics.MetricsCollector.record_metric(
        "test_metric",
        :custom,
        40,
        tags: %{service: "test"}
      )

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
    end

    test "respects cooldown period", %{
      rule_id: rule_id,
      test_name: test_name,
      pid: pid
    } do
      # Record metrics into MetricsCollector
      Raxol.Core.Metrics.MetricsCollector.record_metric(
        "test_metric",
        :custom,
        60,
        tags: %{service: "test"}
      )

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
      # Record metrics into MetricsCollector
      Raxol.Core.Metrics.MetricsCollector.record_metric(
        "test_metric",
        :custom,
        60,
        tags: %{service: "test"}
      )

      # Force alert check only if process is alive
      if Process.alive?(pid) do
        Process.send(test_name, {:check_alerts, 1}, [])
        Process.sleep(100)
      end

      # Acknowledge alert
      assert {:ok, alert_state} =
               AlertManager.acknowledge_alert(rule_id, test_name)

      assert alert_state.acknowledged == true
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
        tags: %{},
        group_by: ["service", "region"]
      }

      {:ok, rule_id} = AlertManager.add_rule(rule, test_name)

      # Record metrics into MetricsCollector
      Raxol.Core.Metrics.MetricsCollector.record_metric(
        "test_metric",
        :custom,
        60,
        tags: %{service: "test", region: "us"}
      )

      Raxol.Core.Metrics.MetricsCollector.record_metric(
        "test_metric",
        :custom,
        40,
        tags: %{service: "test", region: "eu"}
      )

      # Force alert check only if process is alive
      if Process.alive?(pid) do
        Process.send(test_name, {:check_alerts, 1}, [])
      end

      # Wait for alert to become active with retries (CI runners can be slow)
      alert_active =
        Enum.reduce_while(1..20, false, fn _, _acc ->
          Process.sleep(50)

          case AlertManager.get_alert_state(rule_id, test_name) do
            {:ok, %{active: true}} -> {:halt, true}
            _ -> {:cont, false}
          end
        end)

      assert alert_active,
             "Expected alert to become active within 1 second"
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
