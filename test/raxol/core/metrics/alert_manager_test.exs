defmodule Raxol.Core.Metrics.AlertManagerTest do
  @moduledoc """
  Tests for the alert manager, including rule management, alert evaluation,
  acknowledgment, grouped metrics, and error handling.
  """
  use ExUnit.Case, async: true
  alias Raxol.Core.Metrics.AlertManager

  setup do
    {:ok, _pid} = AlertManager.start_link(name: :alert_manager_test)
    :ok
  end

  describe "rule management" do
    test "adds a new alert rule" do
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

      assert {:ok, rule_id} = AlertManager.add_rule(rule, :alert_manager_test)
      assert {:ok, rules} = AlertManager.get_rules(:alert_manager_test)
      assert Map.has_key?(rules, rule_id)
    end

    test "validates and normalizes rule fields" do
      rule = %{
        metric_name: "test_metric",
        threshold: 50
      }

      assert {:ok, rule_id} = AlertManager.add_rule(rule, :alert_manager_test)
      assert {:ok, rules} = AlertManager.get_rules(:alert_manager_test)
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
    setup do
      rule = %{
        name: "Test Alert",
        metric_name: "test_metric",
        condition: :above,
        threshold: 50,
        severity: :warning,
        tags: %{service: "test"}
      }

      {:ok, rule_id} = AlertManager.add_rule(rule, :alert_manager_test)
      %{rule_id: rule_id}
    end

    test "triggers alert when condition is met", %{rule_id: rule_id} do
      metrics = [
        %{
          timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
          value: 60,
          tags: %{service: "test"}
        }
      ]

      try do
        :meck.unload(Raxol.Core.Metrics.UnifiedCollector)
      catch
        :error, {:not_mocked, _} -> :ok
      end

      :meck.new(Raxol.Core.Metrics.UnifiedCollector, [:passthrough])

      :meck.expect(Raxol.Core.Metrics.UnifiedCollector, :get_metrics, fn _name, _tags ->
        metrics
      end)

      # Force alert check
      Process.send(:alert_manager_test, {:check_alerts, 1}, [])

      # Wait for alert to be processed
      Process.sleep(100)

      assert {:ok, alert_state} = AlertManager.get_alert_state(rule_id, :alert_manager_test)
      assert alert_state.active == true
      assert alert_state.current_value == 60

      :meck.unload(Raxol.Core.Metrics.UnifiedCollector)
    end

    test "does not trigger alert when condition is not met", %{rule_id: rule_id} do
      metrics = [
        %{
          timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
          value: 40,
          tags: %{service: "test"}
        }
      ]

      try do
        :meck.unload(Raxol.Core.Metrics.UnifiedCollector)
      catch
        :error, {:not_mocked, _} -> :ok
      end

      :meck.new(Raxol.Core.Metrics.UnifiedCollector, [:passthrough])

      :meck.expect(Raxol.Core.Metrics.UnifiedCollector, :get_metrics, fn _name, _tags ->
        metrics
      end)

      # Force alert check
      Process.send(:alert_manager_test, {:check_alerts, 1}, [])

      # Wait for alert to be processed
      Process.sleep(100)

      assert {:ok, alert_state} = AlertManager.get_alert_state(rule_id, :alert_manager_test)
      assert alert_state.active == false
      assert alert_state.current_value == 40

      :meck.unload(Raxol.Core.Metrics.UnifiedCollector)
    end

    test "respects cooldown period", %{rule_id: rule_id} do
      metrics = [
        %{
          timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
          value: 60,
          tags: %{service: "test"}
        }
      ]

      try do
        :meck.unload(Raxol.Core.Metrics.UnifiedCollector)
      catch
        :error, {:not_mocked, _} -> :ok
      end

      :meck.new(Raxol.Core.Metrics.UnifiedCollector, [:passthrough])

      :meck.expect(Raxol.Core.Metrics.UnifiedCollector, :get_metrics, fn _name, _tags ->
        metrics
      end)

      # Force first alert check
      Process.send(:alert_manager_test, {:check_alerts, 1}, [])
      Process.sleep(100)

      # Force second alert check immediately
      Process.send(:alert_manager_test, {:check_alerts, 2}, [])
      Process.sleep(100)

      assert {:ok, alert_state} = AlertManager.get_alert_state(rule_id, :alert_manager_test)
      assert alert_state.active == false

      # Check alert history
      assert {:ok, history} = AlertManager.get_alert_history(rule_id, :alert_manager_test)
      # Only one alert should be recorded due to cooldown
      assert length(history) == 1

      :meck.unload(Raxol.Core.Metrics.UnifiedCollector)
    end
  end

  describe "alert acknowledgment" do
    setup do
      rule = %{
        name: "Test Alert",
        metric_name: "test_metric",
        condition: :above,
        threshold: 50,
        severity: :warning,
        tags: %{service: "test"}
      }

      {:ok, rule_id} = AlertManager.add_rule(rule, :alert_manager_test)
      %{rule_id: rule_id}
    end

    test "acknowledges an active alert", %{rule_id: rule_id} do
      metrics = [
        %{
          timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
          value: 60,
          tags: %{service: "test"}
        }
      ]

      try do
        :meck.unload(Raxol.Core.Metrics.UnifiedCollector)
      catch
        :error, {:not_mocked, _} -> :ok
      end

      :meck.new(Raxol.Core.Metrics.UnifiedCollector, [:passthrough])

      :meck.expect(Raxol.Core.Metrics.UnifiedCollector, :get_metrics, fn _name, _tags ->
        metrics
      end)

      # Force alert check
      Process.send(:alert_manager_test, {:check_alerts, 1}, [])
      Process.sleep(100)

      # Acknowledge alert
      assert {:ok, alert_state} = AlertManager.acknowledge_alert(rule_id, :alert_manager_test)
      assert alert_state.acknowledged == true

      :meck.unload(Raxol.Core.Metrics.UnifiedCollector)
    end
  end

  describe "grouped metrics" do
    test "evaluates alerts for grouped metrics" do
      rule = %{
        name: "Grouped Alert",
        metric_name: "test_metric",
        condition: :above,
        threshold: 50,
        severity: :warning,
        tags: %{service: "test"},
        group_by: ["service", "region"]
      }

      {:ok, rule_id} = AlertManager.add_rule(rule, :alert_manager_test)

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
        :meck.unload(Raxol.Core.Metrics.UnifiedCollector)
      catch
        :error, {:not_mocked, _} -> :ok
      end

      :meck.new(Raxol.Core.Metrics.UnifiedCollector, [:passthrough])

      :meck.expect(Raxol.Core.Metrics.UnifiedCollector, :get_metrics, fn _name, _tags ->
        metrics
      end)

      # Force alert check
      Process.send(:alert_manager_test, {:check_alerts, 1}, [])
      Process.sleep(100)

      assert {:ok, alert_state} = AlertManager.get_alert_state(rule_id, :alert_manager_test)
      assert alert_state.active == true

      :meck.unload(Raxol.Core.Metrics.UnifiedCollector)
    end
  end

  describe "error handling" do
    test "returns error for non-existent rule" do
      assert {:error, :rule_not_found} = AlertManager.get_alert_state(999, :alert_manager_test)
      assert {:error, :rule_not_found} = AlertManager.get_alert_history(999, :alert_manager_test)
      assert {:error, :rule_not_found} = AlertManager.acknowledge_alert(999, :alert_manager_test)
      assert {:ok, %{}} = AlertManager.get_rules(:alert_manager_test)
    end
  end
end
