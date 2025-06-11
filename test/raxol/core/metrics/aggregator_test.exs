defmodule Raxol.Core.Metrics.AggregatorTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Metrics.Aggregator

  setup do
    {:ok, _pid} = Aggregator.start_link()
    :ok
  end

  describe "rule management" do
    test "adds a new aggregation rule" do
      rule = %{
        type: :mean,
        window: :hour,
        metric_name: "test_metric",
        tags: %{service: "test"},
        group_by: ["service"]
      }

      assert {:ok, rule_id} = Aggregator.add_rule(rule)
      assert {:ok, rules} = Aggregator.get_rules()
      assert Map.has_key?(rules, rule_id)
    end

    test "validates and normalizes rule fields" do
      rule = %{
        metric_name: "test_metric"
      }

      assert {:ok, rule_id} = Aggregator.add_rule(rule)
      assert {:ok, rules} = Aggregator.get_rules()
      stored_rule = rules[rule_id]

      assert stored_rule.type == :mean
      assert stored_rule.window == :hour
      assert stored_rule.tags == %{}
      assert stored_rule.group_by == []
    end
  end

  describe "metric aggregation" do
    setup do
      rule = %{
        type: :mean,
        window: :hour,
        metric_name: "test_metric",
        tags: %{service: "test"},
        group_by: ["service"]
      }
      {:ok, rule_id} = Aggregator.add_rule(rule)
      %{rule_id: rule_id}
    end

    test "aggregates metrics by mean", %{rule_id: rule_id} do
      metrics = [
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 10, tags: %{service: "test"}},
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 20, tags: %{service: "test"}},
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 30, tags: %{service: "test"}}
      ]

      # Mock UnifiedCollector.get_metrics to return our test metrics
      :meck.new(UnifiedCollector, [:passthrough])
      :meck.expect(UnifiedCollector, :get_metrics, fn _name, _tags -> metrics end)

      assert {:ok, aggregated} = Aggregator.update_aggregation(rule_id)
      assert length(aggregated) == 1
      assert aggregated |> List.first() |> Map.get(:value) == 20.0

      :meck.unload(UnifiedCollector)
    end

    test "aggregates metrics by median", %{rule_id: rule_id} do
      rule = %{
        type: :median,
        window: :hour,
        metric_name: "test_metric",
        tags: %{service: "test"},
        group_by: ["service"]
      }
      {:ok, median_rule_id} = Aggregator.add_rule(rule)

      metrics = [
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 10, tags: %{service: "test"}},
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 20, tags: %{service: "test"}},
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 30, tags: %{service: "test"}}
      ]

      :meck.new(UnifiedCollector, [:passthrough])
      :meck.expect(UnifiedCollector, :get_metrics, fn _name, _tags -> metrics end)

      assert {:ok, aggregated} = Aggregator.update_aggregation(median_rule_id)
      assert length(aggregated) == 1
      assert aggregated |> List.first() |> Map.get(:value) == 20.0

      :meck.unload(UnifiedCollector)
    end

    test "groups metrics by specified fields", %{rule_id: rule_id} do
      rule = %{
        type: :mean,
        window: :hour,
        metric_name: "test_metric",
        tags: %{service: "test"},
        group_by: ["service", "region"]
      }
      {:ok, group_rule_id} = Aggregator.add_rule(rule)

      metrics = [
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 10, tags: %{service: "test", region: "us"}},
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 20, tags: %{service: "test", region: "eu"}},
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 30, tags: %{service: "test", region: "us"}}
      ]

      :meck.new(UnifiedCollector, [:passthrough])
      :meck.expect(UnifiedCollector, :get_metrics, fn _name, _tags -> metrics end)

      assert {:ok, aggregated} = Aggregator.update_aggregation(group_rule_id)
      assert length(aggregated) == 2

      us_metrics = Enum.find(aggregated, &(&1.group == "test:us"))
      eu_metrics = Enum.find(aggregated, &(&1.group == "test:eu"))

      assert us_metrics.value == 20.0
      assert eu_metrics.value == 20.0

      :meck.unload(UnifiedCollector)
    end
  end

  describe "error handling" do
    test "returns error for non-existent rule" do
      assert {:error, :rule_not_found} = Aggregator.get_aggregated_metrics(999)
      assert {:error, :rule_not_found} = Aggregator.update_aggregation(999)
    end
  end

  describe "statistical calculations" do
    test "calculates median correctly" do
      rule = %{
        type: :median,
        window: :hour,
        metric_name: "test_metric",
        tags: %{service: "test"}
      }
      {:ok, rule_id} = Aggregator.add_rule(rule)

      metrics = [
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 10, tags: %{service: "test"}},
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 20, tags: %{service: "test"}},
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 30, tags: %{service: "test"}},
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 40, tags: %{service: "test"}}
      ]

      :meck.new(UnifiedCollector, [:passthrough])
      :meck.expect(UnifiedCollector, :get_metrics, fn _name, _tags -> metrics end)

      assert {:ok, aggregated} = Aggregator.update_aggregation(rule_id)
      assert length(aggregated) == 1
      assert aggregated |> List.first() |> Map.get(:value) == 25.0

      :meck.unload(UnifiedCollector)
    end

    test "calculates percentile correctly" do
      rule = %{
        type: :percentile,
        window: :hour,
        metric_name: "test_metric",
        tags: %{service: "test"}
      }
      {:ok, rule_id} = Aggregator.add_rule(rule)

      metrics = [
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 10, tags: %{service: "test"}},
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 20, tags: %{service: "test"}},
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 30, tags: %{service: "test"}},
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 40, tags: %{service: "test"}},
        %{timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond), value: 50, tags: %{service: "test"}}
      ]

      :meck.new(UnifiedCollector, [:passthrough])
      :meck.expect(UnifiedCollector, :get_metrics, fn _name, _tags -> metrics end)

      assert {:ok, aggregated} = Aggregator.update_aggregation(rule_id)
      assert length(aggregated) == 1
      assert aggregated |> List.first() |> Map.get(:value) == 40.0

      :meck.unload(UnifiedCollector)
    end
  end
end
