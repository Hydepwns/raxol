defmodule Raxol.Core.Performance.JankDetector do
  @moduledoc '''
  Detects UI jank by analyzing frame timing.

  A frame is considered janky if it takes longer than the jank threshold
  to render. The detector maintains a rolling window of frame times to
  identify patterns of jank.

  ## Usage

  ```elixir
  # Create a new detector
  detector = JankDetector.new(16, 60)  # 16ms threshold, 60 frame window

  # Record a frame
  detector = JankDetector.record_frame(detector, 20)

  # Check for jank
  if JankDetector.detect_jank?(detector) do
    Raxol.Core.Runtime.Log.warning_with_context("Jank detected", %{})
  end
  ```
  '''

  defstruct [
    :threshold,
    :window_size,
    :frame_times,
    :jank_count
  ]

  @doc '''
  Creates a new jank detector.

  ## Parameters

  * `threshold` - Time in milliseconds above which a frame is considered janky
  * `window_size` - Number of frames to keep in the rolling window

  ## Returns

  A new jank detector struct.

  ## Examples

      iex> JankDetector.new(16, 60)
      %JankDetector{
        threshold: 16,
        window_size: 60,
        frame_times: [],
        jank_count: 0
      }
  '''
  def new(threshold, window_size) do
    %__MODULE__{
      threshold: threshold,
      window_size: window_size,
      frame_times: [],
      jank_count: 0
    }
  end

  @doc '''
  Records a frame's timing.

  ## Parameters

  * `detector` - The jank detector
  * `frame_time` - Time taken to render the frame in milliseconds

  ## Returns

  Updated jank detector.

  ## Examples

      iex> detector = JankDetector.new(16, 60)
      iex> detector = JankDetector.record_frame(detector, 20)
      iex> detector.jank_count
      1
  '''
  def record_frame(detector, frame_time) do
    # Add frame time to window
    frame_times =
      [frame_time | detector.frame_times]
      |> Enum.take(detector.window_size)

    # Count janky frames
    jank_count = Enum.count(frame_times, &(&1 > detector.threshold))

    %{detector | frame_times: frame_times, jank_count: jank_count}
  end

  @doc '''
  Checks if jank was detected in the last frame.

  ## Parameters

  * `detector` - The jank detector

  ## Returns

  * `true` if the last frame was janky
  * `false` otherwise

  ## Examples

      iex> detector = JankDetector.new(16, 60)
      iex> detector = JankDetector.record_frame(detector, 20)
      iex> JankDetector.detect_jank?(detector)
      true
  '''
  def detect_jank?(detector) do
    case detector.frame_times do
      [latest | _] -> latest > detector.threshold
      [] -> false
    end
  end

  @doc '''
  Gets the number of janky frames in the current window.

  ## Parameters

  * `detector` - The jank detector

  ## Returns

  Number of janky frames.

  ## Examples

      iex> detector = JankDetector.new(16, 60)
      iex> detector = JankDetector.record_frame(detector, 20)
      iex> JankDetector.get_jank_count(detector)
      1
  '''
  def get_jank_count(detector), do: detector.jank_count

  @doc '''
  Gets the average frame time in the current window.

  ## Parameters

  * `detector` - The jank detector

  ## Returns

  Average frame time in milliseconds.

  ## Examples

      iex> detector = JankDetector.new(16, 60)
      iex> detector = JankDetector.record_frame(detector, 20)
      iex> JankDetector.get_avg_frame_time(detector)
      20.0
  '''
  def get_avg_frame_time(detector) do
    case detector.frame_times do
      [] -> 0.0
      times -> Enum.sum(times) / length(times)
    end
  end

  @doc '''
  Gets the maximum frame time in the current window.

  ## Parameters

  * `detector` - The jank detector

  ## Returns

  Maximum frame time in milliseconds.

  ## Examples

      iex> detector = JankDetector.new(16, 60)
      iex> detector = JankDetector.record_frame(detector, 20)
      iex> JankDetector.get_max_frame_time(detector)
      20
  '''
  def get_max_frame_time(detector) do
    case detector.frame_times do
      [] -> 0
      times -> Enum.max(times)
    end
  end
end
