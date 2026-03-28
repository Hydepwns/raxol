defmodule Raxol.Terminal.ANSI.KittyAnimation do
  @moduledoc """
  Animation support for the Kitty graphics protocol.

  Provides frame sequencing, playback control, and animation management
  for Kitty terminal graphics. Uses a GenServer for frame scheduling
  and supports various animation modes.

  ## Features

  * Frame-based animation with configurable frame rates
  * Loop modes: once, infinite, ping-pong
  * Frame timing control
  * Animation state management
  * Integration with KittyGraphics

  ## Usage

      # Create an animation
      {:ok, anim} = KittyAnimation.create_animation(%{
        width: 100,
        height: 100,
        frame_rate: 30
      })

      # Add frames
      anim = KittyAnimation.add_frame(anim, frame1_data)
      anim = KittyAnimation.add_frame(anim, frame2_data)

      # Start playback
      {:ok, pid} = KittyAnimation.start(anim)

      # Control playback
      KittyAnimation.pause(pid)
      KittyAnimation.resume(pid)
      KittyAnimation.stop(pid)
  """

  use GenServer

  alias Raxol.Terminal.ANSI.KittyGraphics

  @type loop_mode :: :once | :infinite | :ping_pong
  @type playback_state :: :stopped | :playing | :paused

  @type frame :: %{
          data: binary(),
          duration_ms: non_neg_integer(),
          index: non_neg_integer()
        }

  @type t :: %__MODULE__{
          image_id: non_neg_integer() | nil,
          width: non_neg_integer(),
          height: non_neg_integer(),
          format: KittyGraphics.format(),
          frames: [frame()],
          current_frame: non_neg_integer(),
          frame_rate: pos_integer(),
          loop_mode: loop_mode(),
          loop_count: non_neg_integer(),
          direction: :forward | :backward,
          state: playback_state(),
          on_frame: (frame() -> :ok) | nil,
          on_complete: (-> :ok) | nil
        }

  defstruct image_id: nil,
            width: 0,
            height: 0,
            format: :rgba,
            frames: [],
            current_frame: 0,
            frame_rate: 30,
            loop_mode: :infinite,
            loop_count: 0,
            direction: :forward,
            state: :stopped,
            on_frame: nil,
            on_complete: nil

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Creates a new animation with the given options.

  ## Options

  * `:width` - Image width in pixels (required)
  * `:height` - Image height in pixels (required)
  * `:format` - Image format (:rgb, :rgba, :png), defaults to :rgba
  * `:frame_rate` - Frames per second, defaults to 30
  * `:loop_mode` - Loop mode (:once, :infinite, :ping_pong), defaults to :infinite
  * `:image_id` - Optional image ID for the animation

  ## Returns

  * `{:ok, animation}` - New animation struct
  * `{:error, reason}` - If required options are missing
  """
  @spec create_animation(map()) :: {:ok, t()} | {:error, term()}
  def create_animation(opts) do
    width = Map.get(opts, :width)
    height = Map.get(opts, :height)

    case {width, height} do
      {w, h} when is_integer(w) and is_integer(h) and w > 0 and h > 0 ->
        animation = %__MODULE__{
          image_id: Map.get(opts, :image_id, generate_image_id()),
          width: w,
          height: h,
          format: Map.get(opts, :format, :rgba),
          frames: [],
          frame_rate: Map.get(opts, :frame_rate, 30),
          loop_mode: Map.get(opts, :loop_mode, :infinite),
          on_frame: Map.get(opts, :on_frame),
          on_complete: Map.get(opts, :on_complete)
        }

        {:ok, animation}

      _ ->
        {:error, :invalid_dimensions}
    end
  end

  @doc """
  Adds a frame to the animation.

  ## Parameters

  * `animation` - The animation struct
  * `frame_data` - Binary pixel data for the frame
  * `opts` - Optional frame options:
    * `:duration_ms` - Frame duration override in milliseconds

  ## Returns

  The updated animation with the new frame added.
  """
  @spec add_frame(t(), binary(), keyword()) :: t()
  def add_frame(animation, frame_data, opts \\ []) when is_binary(frame_data) do
    default_duration = div(1000, animation.frame_rate)
    duration = Keyword.get(opts, :duration_ms, default_duration)

    frame = %{
      data: frame_data,
      duration_ms: duration,
      index: length(animation.frames)
    }

    %{animation | frames: animation.frames ++ [frame]}
  end

  @doc """
  Gets the current frame from the animation.

  ## Parameters

  * `animation` - The animation struct

  ## Returns

  The current frame struct, or nil if no frames exist.
  """
  @spec get_frame(t()) :: frame() | nil
  def get_frame(animation) do
    Enum.at(animation.frames, animation.current_frame)
  end

  @doc """
  Gets a frame by index.

  ## Parameters

  * `animation` - The animation struct
  * `index` - The frame index

  ## Returns

  The frame at the specified index, or nil if not found.
  """
  @spec get_frame(t(), non_neg_integer()) :: frame() | nil
  def get_frame(animation, index) when is_integer(index) and index >= 0 do
    Enum.at(animation.frames, index)
  end

  @doc """
  Advances to the next frame.

  Handles loop modes and direction for ping-pong animations.

  ## Parameters

  * `animation` - The animation struct

  ## Returns

  * `{:ok, updated_animation}` - Animation advanced to next frame
  * `{:complete, animation}` - Animation completed (for :once mode)
  """
  @spec next_frame(t()) :: {:ok, t()} | {:complete, t()}
  def next_frame(%{frames: []} = animation), do: {:complete, animation}

  def next_frame(animation) do
    total_frames = length(animation.frames)

    {next_index, new_direction, completed} =
      calculate_next_frame(
        animation.current_frame,
        total_frames,
        animation.direction,
        animation.loop_mode,
        animation.loop_count
      )

    case completed do
      true ->
        {:complete, %{animation | state: :stopped}}

      false ->
        updated = %{
          animation
          | current_frame: next_index,
            direction: new_direction,
            loop_count: maybe_increment_loop(animation, next_index)
        }

        {:ok, updated}
    end
  end

  @doc """
  Starts playback of the animation as a GenServer process.

  ## Parameters

  * `animation` - The animation struct
  * `opts` - GenServer start options

  ## Returns

  * `{:ok, pid}` - The animation player process
  * `{:error, reason}` - If start fails
  """
  @spec start(t(), keyword()) :: GenServer.on_start()
  def start(animation, opts \\ []) do
    GenServer.start(__MODULE__, animation, opts)
  end

  @doc """
  Starts playback (for already running process).

  ## Parameters

  * `pid` - The animation player process

  ## Returns

  `:ok`
  """
  @spec play(GenServer.server()) :: :ok
  def play(pid) do
    GenServer.cast(pid, :play)
  end

  @doc """
  Pauses playback.

  ## Parameters

  * `pid` - The animation player process

  ## Returns

  `:ok`
  """
  @spec pause(GenServer.server()) :: :ok
  def pause(pid) do
    GenServer.cast(pid, :pause)
  end

  @doc """
  Resumes playback from current frame.

  ## Parameters

  * `pid` - The animation player process

  ## Returns

  `:ok`
  """
  @spec resume(GenServer.server()) :: :ok
  def resume(pid) do
    GenServer.cast(pid, :resume)
  end

  @doc """
  Stops playback and resets to first frame.

  ## Parameters

  * `pid` - The animation player process

  ## Returns

  `:ok`
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(pid) do
    GenServer.cast(pid, :stop)
  end

  @doc """
  Gets the current animation state.

  ## Parameters

  * `pid` - The animation player process

  ## Returns

  The current animation struct.
  """
  @spec get_state(GenServer.server()) :: t()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Seeks to a specific frame.

  ## Parameters

  * `pid` - The animation player process
  * `frame_index` - The frame to seek to

  ## Returns

  `:ok`
  """
  @spec seek(GenServer.server(), non_neg_integer()) :: :ok
  def seek(pid, frame_index) do
    GenServer.cast(pid, {:seek, frame_index})
  end

  @doc """
  Sets the frame rate during playback.

  ## Parameters

  * `pid` - The animation player process
  * `fps` - Frames per second

  ## Returns

  `:ok`
  """
  @spec set_frame_rate(GenServer.server(), pos_integer()) :: :ok
  def set_frame_rate(pid, fps) when is_integer(fps) and fps > 0 do
    GenServer.cast(pid, {:set_frame_rate, fps})
  end

  @doc """
  Sets the loop mode during playback.

  ## Parameters

  * `pid` - The animation player process
  * `mode` - Loop mode (:once, :infinite, :ping_pong)

  ## Returns

  `:ok`
  """
  @spec set_loop_mode(GenServer.server(), loop_mode()) :: :ok
  def set_loop_mode(pid, mode) when mode in [:once, :infinite, :ping_pong] do
    GenServer.cast(pid, {:set_loop_mode, mode})
  end

  @doc """
  Generates Kitty protocol escape sequences for the animation.

  ## Parameters

  * `animation` - The animation struct

  ## Returns

  A list of escape sequences for each frame.
  """
  @spec generate_sequences(t()) :: [binary()]
  def generate_sequences(animation) do
    animation.frames
    |> Enum.with_index()
    |> Enum.map(fn {frame, index} ->
      image =
        %KittyGraphics{
          width: animation.width,
          height: animation.height,
          format: animation.format,
          image_id: animation.image_id,
          pixel_buffer: frame.data
        }

      # First frame uses transmit+display, subsequent frames use animation frame action
      case index do
        0 -> KittyGraphics.encode(image)
        _ -> generate_frame_command(animation.image_id, frame, index)
      end
    end)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(animation) do
    {:ok, %{animation | state: :stopped}}
  end

  @impl true
  def handle_cast(:play, animation) do
    case animation.state do
      :playing ->
        {:noreply, animation}

      _ ->
        schedule_frame(animation)
        {:noreply, %{animation | state: :playing}}
    end
  end

  @impl true
  def handle_cast(:pause, animation) do
    {:noreply, %{animation | state: :paused}}
  end

  @impl true
  def handle_cast(:resume, animation) do
    case animation.state do
      :paused ->
        schedule_frame(animation)
        {:noreply, %{animation | state: :playing}}

      _ ->
        {:noreply, animation}
    end
  end

  @impl true
  def handle_cast(:stop, animation) do
    {:noreply, %{animation | state: :stopped, current_frame: 0, loop_count: 0}}
  end

  @impl true
  def handle_cast({:seek, frame_index}, animation) do
    total = length(animation.frames)
    valid_index = min(max(0, frame_index), total - 1)
    {:noreply, %{animation | current_frame: valid_index}}
  end

  @impl true
  def handle_cast({:set_frame_rate, fps}, animation) do
    {:noreply, %{animation | frame_rate: fps}}
  end

  @impl true
  def handle_cast({:set_loop_mode, mode}, animation) do
    {:noreply, %{animation | loop_mode: mode}}
  end

  @impl true
  def handle_call(:get_state, _from, animation) do
    {:reply, animation, animation}
  end

  @impl true
  def handle_info(:tick, %{state: :playing} = animation) do
    # Execute frame callback if provided
    frame = get_frame(animation)

    if frame && animation.on_frame do
      animation.on_frame.(frame)
    end

    case next_frame(animation) do
      {:ok, updated} ->
        schedule_frame(updated)
        {:noreply, updated}

      {:complete, updated} ->
        if updated.on_complete do
          updated.on_complete.()
        end

        {:noreply, updated}
    end
  end

  @impl true
  def handle_info(:tick, animation) do
    # Not playing, ignore tick
    {:noreply, animation}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp schedule_frame(animation) do
    frame = get_frame(animation)

    delay =
      if frame, do: frame.duration_ms, else: div(1000, animation.frame_rate)

    Process.send_after(self(), :tick, delay)
  end

  defp calculate_next_frame(current, total, direction, loop_mode, _loop_count) do
    case {direction, loop_mode} do
      {:forward, :once} ->
        next = current + 1

        case next >= total do
          true -> {current, :forward, true}
          false -> {next, :forward, false}
        end

      {:forward, :infinite} ->
        {rem(current + 1, total), :forward, false}

      {:forward, :ping_pong} ->
        next = current + 1

        case next >= total do
          true -> {current - 1, :backward, false}
          false -> {next, :forward, false}
        end

      {:backward, :ping_pong} ->
        prev = current - 1

        case prev < 0 do
          true -> {1, :forward, false}
          false -> {prev, :backward, false}
        end

      {dir, _} ->
        # Default forward behavior
        {rem(current + 1, total), dir, false}
    end
  end

  defp maybe_increment_loop(animation, next_index) do
    case {next_index, animation.loop_mode} do
      {0, :infinite} ->
        animation.loop_count + 1

      {0, :ping_pong} when animation.direction == :forward ->
        animation.loop_count + 1

      _ ->
        animation.loop_count
    end
  end

  defp generate_frame_command(image_id, frame, frame_index) do
    # Kitty animation frame command
    control = "a=f,i=#{image_id},r=#{frame_index},z=#{frame.duration_ms}"
    encoded_data = Base.encode64(frame.data)

    "\e_G#{control};#{encoded_data}\e\\"
  end

  defp generate_image_id do
    :erlang.unique_integer([:positive, :monotonic])
  end
end
