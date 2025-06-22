defmodule Raxol.Core.Metrics.ConfigTest do
  @moduledoc """
  Tests for the metrics configuration system, including validation,
  default values, and configuration updates.
  """
  use ExUnit.Case, async: false
  import Raxol.Guards
  alias Raxol.Core.Metrics.Config

  setup do
    {:ok, _pid} = Config.start_link()
    on_exit(fn -> :ok = Config.reset() end)
    :ok
  end

  describe "configuration initialization" do
    test "loads default configuration" do
      assert {:ok, config} = Config.get_all()
      assert map?(config) and Map.has_key?(config, :aggregation_window)
      assert config.aggregation_window == :hour
      assert config.storage_backend == :memory
      assert list?(config.retention_policies)
    end

    test "loads custom configuration" do
      custom_config = %{
        aggregation_window: :day,
        storage_backend: :disk,
        retention_policies: [
          %{metric: "test_metric", duration: "7d"}
        ]
      }

      assert :ok = Config.update(custom_config)
      assert {:ok, config} = Config.get_all()
      assert config.aggregation_window == :day
      assert config.storage_backend == :disk
      assert length(config.retention_policies) == 1
    end
  end

  describe "configuration validation" do
    test "validates aggregation window" do
      assert {:error, _} = Config.set(:aggregation_window, :invalid)
      assert :ok = Config.set(:aggregation_window, :hour)
      assert :ok = Config.set(:aggregation_window, :day)
    end

    test "validates storage backend" do
      assert {:error, _} = Config.set(:storage_backend, :invalid)
      assert :ok = Config.set(:storage_backend, :memory)
      assert :ok = Config.set(:storage_backend, :disk)
    end

    test "validates retention policies" do
      valid_policy = %{metric: "test_metric", duration: "7d"}
      invalid_policy = %{metric: "test_metric", duration: "invalid"}

      assert :ok = Config.set(:retention_policies, [valid_policy])
      assert {:error, _} = Config.set(:retention_policies, [invalid_policy])
    end
  end

  describe "configuration updates" do
    test "updates individual settings" do
      assert :ok = Config.set(:aggregation_window, :day)
      assert {:ok, config} = Config.get_all()
      assert config.aggregation_window == :day
    end

    test "updates multiple settings" do
      updates = %{
        aggregation_window: :day,
        storage_backend: :disk
      }

      assert :ok = Config.update(updates)
      assert {:ok, config} = Config.get_all()
      assert config.aggregation_window == :day
      assert config.storage_backend == :disk
    end

    test "resets to defaults" do
      assert :ok = Config.set(:aggregation_window, :day)
      assert :ok = Config.reset()
      assert {:ok, config} = Config.get_all()
      assert config.aggregation_window == :hour
    end
  end

  describe "error handling" do
    test "handles invalid configuration keys" do
      assert {:error, :invalid_key} = Config.set(:invalid_key, "value")
    end

    test "handles invalid configuration values" do
      assert {:error, _} = Config.set(:aggregation_window, "invalid")
      assert {:error, _} = Config.set(:storage_backend, 123)
    end

    test "handles invalid retention policy format" do
      invalid_policies = [
        %{invalid: "format"},
        %{metric: "test", duration: 123}
      ]

      assert {:error, _} = Config.set(:retention_policies, invalid_policies)
    end
  end
end
