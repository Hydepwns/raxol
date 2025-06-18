defmodule Raxol.Test.MetricsHelperTest do
  use ExUnit.Case
  alias Raxol.Test.MetricsHelper

  setup do
    context = MetricsHelper.setup_metrics_test()
    on_exit(fn -> MetricsHelper.cleanup_metrics_test(context) end)
    {:ok, context}
  end

  describe "setup_metrics_test/1" do
    test ~c"starts metrics collector with default options" do
      context = MetricsHelper.setup_metrics_test()
      assert Process.whereis(Raxol.Core.Metrics.UnifiedCollector)
      MetricsHelper.cleanup_metrics_test(context)
    end

    test ~c"starts metrics collector with custom options" do
      context =
        MetricsHelper.setup_metrics_test(
          retention_period: 120,
          max_samples: 200,
          flush_interval: 2000
        )

      assert Process.whereis(Raxol.Core.Metrics.UnifiedCollector)
      MetricsHelper.cleanup_metrics_test(context)
    end

    test ~c"can start without collector" do
      context = MetricsHelper.setup_metrics_test(start_collector: false)
      refute Process.whereis(Raxol.Core.Metrics.UnifiedCollector)
      MetricsHelper.cleanup_metrics_test(context)
    end
  end

  describe "record_test_metric/4" do
    test ~c"records performance metrics" do
      :ok = MetricsHelper.record_test_metric(:performance, :frame_time, 16)
      assert :ok == MetricsHelper.verify_metric(:performance, :frame_time, 16)
    end

    test ~c"records resource metrics" do
      :ok = MetricsHelper.record_test_metric(:resource, :memory_usage, 1024)
      assert :ok == MetricsHelper.verify_metric(:resource, :memory_usage, 1024)
    end

    test ~c"records operation metrics" do
      :ok = MetricsHelper.record_test_metric(:operation, :buffer_write, 5)
      assert :ok == MetricsHelper.verify_metric(:operation, :buffer_write, 5)
    end

    test ~c"records custom metrics" do
      :ok = MetricsHelper.record_test_metric(:custom, "user.login_time", 150)
      assert :ok == MetricsHelper.verify_metric(:custom, "user.login_time", 150)
    end

    test ~c"records metrics with tags" do
      :ok =
        MetricsHelper.record_test_metric(:performance, :frame_time, 16,
          tags: [:test, :ui]
        )

      assert :ok ==
               MetricsHelper.verify_metric(:performance, :frame_time, 16,
                 tags: [:test, :ui]
               )
    end
  end

  describe "verify_metric/4" do
    test ~c"verifies metric value" do
      :ok = MetricsHelper.record_test_metric(:performance, :frame_time, 16)
      assert :ok == MetricsHelper.verify_metric(:performance, :frame_time, 16)
    end

    test ~c"returns error for non-existent metric" do
      assert {:error, :metric_not_found} ==
               MetricsHelper.verify_metric(:performance, :non_existent, 16)
    end

    test ~c"returns error for unexpected value" do
      :ok = MetricsHelper.record_test_metric(:performance, :frame_time, 16)

      assert {:error, {:unexpected_value, 16, 32}} ==
               MetricsHelper.verify_metric(:performance, :frame_time, 32)
    end

    test ~c"verifies metric tags" do
      :ok =
        MetricsHelper.record_test_metric(:performance, :frame_time, 16,
          tags: [:test, :ui]
        )

      assert :ok ==
               MetricsHelper.verify_metric(:performance, :frame_time, 16,
                 tags: [:test, :ui]
               )
    end

    test ~c"returns error for unexpected tags" do
      :ok =
        MetricsHelper.record_test_metric(:performance, :frame_time, 16,
          tags: [:test]
        )

      assert {:error, {:unexpected_tags, [:test], [:test, :ui]}} ==
               MetricsHelper.verify_metric(:performance, :frame_time, 16,
                 tags: [:test, :ui]
               )
    end
  end

  describe "wait_for_metric/4" do
    test ~c"waits for metric to be recorded" do
      spawn(fn ->
        Process.sleep(100)
        MetricsHelper.record_test_metric(:performance, :frame_time, 16)
      end)

      assert :ok == MetricsHelper.wait_for_metric(:performance, :frame_time, 16)
    end

    test ~c"times out waiting for metric" do
      assert {:error, :timeout} ==
               MetricsHelper.wait_for_metric(:performance, :frame_time, 16,
                 timeout: 100
               )
    end

    test ~c"waits for metric with tags" do
      spawn(fn ->
        Process.sleep(100)

        MetricsHelper.record_test_metric(:performance, :frame_time, 16,
          tags: [:test]
        )
      end)

      assert :ok ==
               MetricsHelper.wait_for_metric(:performance, :frame_time, 16,
                 tags: [:test],
                 timeout: 200
               )
    end

    test ~c"times out waiting for metric with tags" do
      assert {:error, :timeout} ==
               MetricsHelper.wait_for_metric(:performance, :frame_time, 16,
                 tags: [:test],
                 timeout: 100
               )
    end
  end

  describe "cleanup_metrics_test/1" do
    test ~c"stops metrics collector" do
      context = MetricsHelper.setup_metrics_test()
      assert Process.whereis(Raxol.Core.Metrics.UnifiedCollector)
      :ok = MetricsHelper.cleanup_metrics_test(context)
      refute Process.whereis(Raxol.Core.Metrics.UnifiedCollector)
    end

    test ~c"handles already stopped collector" do
      context = MetricsHelper.setup_metrics_test(start_collector: false)
      :ok = MetricsHelper.cleanup_metrics_test(context)
      refute Process.whereis(Raxol.Core.Metrics.UnifiedCollector)
    end
  end
end
