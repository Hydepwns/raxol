defmodule Raxol.Performance.JankDetectorTest do
  @moduledoc """
  Tests for the jank detector, including frame time recording,
  jank detection, window size management, and error handling.
  """
  use ExUnit.Case

  alias Raxol.Performance.JankDetector

  describe "Jank Detector" do
    test "creates new detector with default settings" do
      detector = JankDetector.new(16, 60)

      assert detector.threshold == 16
      assert detector.window_size == 60
      assert detector.frame_times == []
      assert detector.jank_count == 0
    end

    test "records frame time" do
      detector = JankDetector.new(16, 60)
      detector = JankDetector.record_frame(detector, 16)

      assert length(detector.frame_times) == 1
      assert hd(detector.frame_times) == 16
    end

    test "detects jank when frame time exceeds threshold" do
      detector = JankDetector.new(16, 60)
      detector = JankDetector.record_frame(detector, 20)

      assert true == JankDetector.detect_jank?(detector)
      assert detector.jank_count == 1
    end

    test "does not detect jank when frame time is below threshold" do
      detector = JankDetector.new(16, 60)
      detector = JankDetector.record_frame(detector, 16)

      assert false == JankDetector.detect_jank?(detector)
      assert detector.jank_count == 0
    end

    test "maintains window size limit" do
      detector = JankDetector.new(16, 3)

      # Record more frames than window size
      detector =
        Enum.reduce(1..5, detector, fn _, acc ->
          JankDetector.record_frame(acc, 16)
        end)

      assert length(detector.frame_times) == 3
    end

    test "calculates average frame time correctly" do
      detector = JankDetector.new(16, 60)

      # Record some frames
      detector =
        Enum.reduce([16, 20, 24], detector, fn time, acc ->
          JankDetector.record_frame(acc, time)
        end)

      assert_in_delta JankDetector.get_avg_frame_time(detector), 20.0, 0.1
    end

    test "handles empty frame times" do
      detector = JankDetector.new(16, 60)

      assert JankDetector.get_avg_frame_time(detector) == 0.0
      assert JankDetector.get_max_frame_time(detector) == 0
      assert JankDetector.get_jank_count(detector) == 0
    end

    test "tracks jank count in window" do
      detector = JankDetector.new(16, 60)

      # Record mix of janky and non-janky frames
      detector =
        Enum.reduce([16, 20, 16, 24, 16], detector, fn time, acc ->
          JankDetector.record_frame(acc, time)
        end)

      # 20ms and 24ms frames
      assert detector.jank_count == 2
    end

    test "updates jank count when window changes" do
      detector = JankDetector.new(16, 3)

      # Record janky frames
      detector =
        Enum.reduce([20, 20, 20], detector, fn _, acc ->
          JankDetector.record_frame(acc, 20)
        end)

      assert detector.jank_count == 3

      # Add non-janky frame, pushing out a janky one
      detector = JankDetector.record_frame(detector, 16)

      assert detector.jank_count == 2
    end
  end
end
