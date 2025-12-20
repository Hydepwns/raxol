defmodule Raxol.Terminal.Graphics.GraphicsServer do
  @moduledoc """
  Provides unified graphics capabilities for the terminal emulator with automatic
  protocol detection and fallback support.

  This module handles:
  * Automatic graphics protocol detection (Kitty, iTerm2, Sixel)
  * Protocol-agnostic image display interface
  * Graceful fallback between supported protocols
  * Graphics state management and context switching
  * Performance optimization and caching

  ## Supported Protocols

  * **Kitty Graphics Protocol** - High-performance, supports animations and transparency
  * **iTerm2 Inline Images** - Good compatibility, limited animation support
  * **Sixel Graphics** - Wide terminal support, basic image display
  * **Fallback Mode** - ASCII art conversion for unsupported terminals

  ## Usage

      # Automatic protocol detection and image display
      {:ok, _} = GraphicsServer.display_image(image_data, %{
        width: 300,
        height: 200,
        format: :png
      })

      # Query available protocols
      graphics_info = GraphicsServer.get_graphics_info()

  """

  use Raxol.Core.Behaviours.BaseManager

  alias Raxol.System.Platform
  alias Raxol.Terminal.ANSI.SixelGraphics
  alias Raxol.Terminal.Graphics.ImageCache
  alias Raxol.Terminal.Graphics.ImageProcessor
  alias Raxol.Terminal.Graphics.KittyProtocol

  # Types
  @type graphics_id :: non_neg_integer()
  @type graphics_state :: :active | :inactive | :hidden
  @type graphics_protocol :: :kitty | :iterm2 | :sixel | :fallback
  @type image_format :: :rgb | :rgba | :png | :jpeg | :webp | :gif
  @type graphics_config :: %{
          optional(:width) => non_neg_integer(),
          optional(:height) => non_neg_integer(),
          optional(:format) => image_format(),
          optional(:compression) => :none | :zlib | :lz4,
          optional(:quality) => 0..100,
          optional(:protocol) => graphics_protocol(),
          optional(:fallback_enabled) => boolean()
        }

  @type display_options :: %{
          optional(:x) => non_neg_integer(),
          optional(:y) => non_neg_integer(),
          optional(:width) => non_neg_integer(),
          optional(:height) => non_neg_integer(),
          optional(:scale) => float(),
          optional(:preserve_aspect_ratio) => boolean(),
          optional(:protocol) => graphics_protocol(),
          optional(:quality) => 1..100,
          optional(:dither) => :none | :riemersma | :floyd_steinberg | :ordered,
          optional(:color_optimization) => boolean(),
          optional(:cache_enabled) => boolean(),
          optional(:processing_options) => map()
        }

  # Client API
  @doc """
  Creates a new graphics context with the given configuration.
  """
  @spec create_graphics(map()) :: {:ok, graphics_id()} | {:error, term()}
  def create_graphics(config \\ %{}) do
    GenServer.call(__MODULE__, {:create_graphics, config})
  end

  @doc """
  Gets the list of all graphics contexts.
  """
  @spec get_graphics() :: list(graphics_id())
  def get_graphics do
    GenServer.call(__MODULE__, :get_graphics)
  end

  @doc """
  Gets the active graphics context ID.
  """
  @spec get_active_graphics() ::
          {:ok, graphics_id()} | {:error, :no_active_graphics}
  def get_active_graphics do
    GenServer.call(__MODULE__, :get_active_graphics)
  end

  @doc """
  Sets the active graphics context.
  """
  @spec set_active_graphics(graphics_id()) :: :ok | {:error, term()}
  def set_active_graphics(graphics_id) do
    GenServer.call(__MODULE__, {:set_active_graphics, graphics_id})
  end

  @doc """
  Gets the state of a specific graphics context.
  """
  @spec get_graphics_state(graphics_id()) :: {:ok, map()} | {:error, term()}
  def get_graphics_state(graphics_id) do
    GenServer.call(__MODULE__, {:get_graphics_state, graphics_id})
  end

  @doc """
  Updates the configuration of a specific graphics context.
  """
  @spec update_graphics_config(graphics_id(), graphics_config()) ::
          :ok | {:error, term()}
  def update_graphics_config(graphics_id, config) do
    GenServer.call(__MODULE__, {:update_graphics_config, graphics_id, config})
  end

  @doc """
  Renders graphics data to the specified context.
  """
  @spec render_graphics(graphics_id(), binary()) :: :ok | {:error, term()}
  def render_graphics(graphics_id, data) do
    GenServer.call(__MODULE__, {:render_graphics, graphics_id, data})
  end

  @doc """
  Clears the graphics context.
  """
  @spec clear_graphics(graphics_id()) :: :ok | {:error, term()}
  def clear_graphics(graphics_id) do
    GenServer.call(__MODULE__, {:clear_graphics, graphics_id})
  end

  @doc """
  Closes a graphics context.
  """
  @spec close_graphics(graphics_id()) :: :ok | {:error, term()}
  def close_graphics(graphics_id) do
    GenServer.call(__MODULE__, {:close_graphics, graphics_id})
  end

  @doc """
  Updates the graphics manager configuration.
  """
  @spec update_config(map()) :: :ok
  def update_config(config) do
    GenServer.call(__MODULE__, {:update_config, config})
  end

  @doc """
  Displays an image using the best available graphics protocol.

  Automatically detects the optimal protocol and falls back gracefully
  if the preferred protocol is not supported.

  ## Parameters

  - `image_data` - Binary image data or file path
  - `options` - Display options including size, position, format

  ## Returns

  - `{:ok, graphics_id}` - Successfully displayed image
  - `{:error, reason}` - Error with reason

  ## Examples

      # Display PNG image with automatic protocol detection
      {:ok, id} = GraphicsServer.display_image(png_data, %{
        width: 300,
        height: 200,
        format: :png
      })

      # Display with specific protocol preference
      {:ok, id} = GraphicsServer.display_image(image_data, %{
        width: 400,
        height: 300,
        protocol: :kitty,
        fallback_enabled: true
      })
  """
  @spec display_image(binary() | String.t(), display_options()) ::
          {:ok, graphics_id()} | {:error, term()}
  def display_image(image_data, options \\ %{}) do
    GenServer.call(__MODULE__, {:display_image, image_data, options})
  end

  @doc """
  Gets information about available graphics protocols and capabilities.

  ## Returns

  A map containing:
  - `:supported_protocols` - List of supported protocols
  - `:preferred_protocol` - Recommended protocol for best performance
  - `:terminal_info` - Detected terminal information
  - `:capabilities` - Protocol-specific capabilities

  ## Examples

      iex> GraphicsServer.get_graphics_info()
      %{
        supported_protocols: [:kitty, :sixel],
        preferred_protocol: :kitty,
        terminal_info: %{type: :kitty, version: "0.26.5"},
        capabilities: %{
          kitty: %{max_image_size: 100_000_000, supports_animation: true},
          sixel: %{max_image_size: 1_000_000, supports_animation: false}
        }
      }
  """
  @spec get_graphics_info() :: map()
  def get_graphics_info do
    GenServer.call(__MODULE__, :get_graphics_info)
  end

  @doc """
  Creates an animation from multiple image frames.

  ## Parameters

  - `frames` - List of image data for animation frames
  - `options` - Animation options (frame_delay, loop_count, protocol)

  ## Returns

  - `{:ok, graphics_id}` - Successfully created animation
  - `{:error, reason}` - Error with reason
  """
  @spec create_animation([binary()], map()) ::
          {:ok, graphics_id()} | {:error, term()}
  def create_animation(frames, options \\ %{}) do
    GenServer.call(__MODULE__, {:create_animation, frames, options})
  end

  @doc """
  Sets the preferred graphics protocol for future operations.

  ## Parameters

  - `protocol` - Preferred protocol (:kitty, :iterm2, :sixel, :auto)
  - `fallback_enabled` - Whether to enable fallback to other protocols

  ## Returns

  - `:ok` - Protocol preference updated
  - `{:error, reason}` - Error with reason
  """
  @spec set_preferred_protocol(graphics_protocol() | :auto, boolean()) ::
          :ok | {:error, term()}
  def set_preferred_protocol(protocol, fallback_enabled \\ true) do
    GenServer.call(
      __MODULE__,
      {:set_preferred_protocol, protocol, fallback_enabled}
    )
  end

  @doc """
  Updates properties of an existing graphics element for animation purposes.

  ## Parameters

  - `graphics_id` - ID of the graphics element to update
  - `properties` - Map of properties to update (opacity, position, scale, etc.)

  ## Returns

  - `:ok` - Properties updated successfully
  - `{:error, reason}` - Update failed
  """
  @spec update_graphics_properties(graphics_id(), map()) ::
          :ok | {:error, term()}
  def update_graphics_properties(graphics_id, properties) do
    GenServer.call(
      __MODULE__,
      {:update_graphics_properties, graphics_id, properties}
    )
  end

  @doc """
  Processes and displays multiple images with optimized format conversion.

  Automatically detects image formats, applies appropriate processing,
  and selects the best display protocol for each image.

  ## Parameters

  - `images` - List of image data or {data, options} tuples
  - `shared_options` - Options applied to all images

  ## Returns

  - `{:ok, [graphics_id]}` - Successfully processed and displayed images
  - `{:error, reason}` - Processing failed

  ## Examples

      # Process multiple images with shared settings
      {:ok, ids} = GraphicsServer.display_images([
        png_data,
        {jpeg_data, %{quality: 95}},
        svg_data
      ], %{
        width: 300,
        height: 200,
        optimize_for_terminal: true
      })
  """
  @spec display_images(
          [binary() | {binary(), display_options()}],
          display_options()
        ) ::
          {:ok, [graphics_id()]} | {:error, term()}
  def display_images(images, shared_options \\ %{}) do
    GenServer.call(__MODULE__, {:display_images, images, shared_options})
  end

  @doc """
  Converts an image from one format to another with display optimization.

  ## Parameters

  - `image_data` - Source image data
  - `target_format` - Target format (:png, :jpeg, :webp, :gif)
  - `options` - Conversion and display options

  ## Returns

  - `{:ok, graphics_id}` - Successfully converted and displayed
  - `{:error, reason}` - Conversion failed
  """
  @spec convert_and_display(binary(), image_format(), display_options()) ::
          {:ok, graphics_id()} | {:error, term()}
  def convert_and_display(image_data, target_format, options \\ %{}) do
    GenServer.call(
      __MODULE__,
      {:convert_and_display, image_data, target_format, options}
    )
  end

  @doc """
  Creates optimized variants for different terminal capabilities.

  Generates multiple versions of an image optimized for different
  terminal types and automatically selects the best one to display.

  ## Parameters

  - `image_data` - Source image data
  - `options` - Processing and display options

  ## Returns

  - `{:ok, graphics_id}` - Successfully optimized and displayed
  - `{:error, reason}` - Optimization failed
  """
  @spec optimize_and_display(binary(), display_options()) ::
          {:ok, graphics_id()} | {:error, term()}
  def optimize_and_display(image_data, options \\ %{}) do
    GenServer.call(__MODULE__, {:optimize_and_display, image_data, options})
  end

  @doc """
  Gets comprehensive information about a processed image.

  ## Parameters

  - `graphics_id` - ID of previously processed image

  ## Returns

  - `{:ok, image_info}` - Image metadata and processing information
  - `{:error, reason}` - Image not found or error
  """
  @spec get_image_info(graphics_id()) :: {:ok, map()} | {:error, term()}
  def get_image_info(graphics_id) do
    GenServer.call(__MODULE__, {:get_image_info, graphics_id})
  end

  @doc """
  Manages the image cache for performance optimization.

  ## Parameters

  - `action` - Cache action (:get_stats, :clear, :configure)
  - `params` - Optional parameters for the action

  ## Returns

  - Cache operation result
  """
  @spec manage_cache(atom(), map()) :: term()
  def manage_cache(action, params \\ %{}) do
    GenServer.call(__MODULE__, {:manage_cache, action, params})
  end

  @doc """
  Cleans up resources.
  """
  @spec cleanup() :: :ok
  def cleanup do
    GenServer.call(__MODULE__, :cleanup)
  end

  # Server Callbacks
  @impl true
  def init_manager(opts) do
    # Detect graphics capabilities on startup
    graphics_support = Platform.detect_graphics_support()

    # Start image cache if enabled
    cache_config = Keyword.get(opts, :cache_config, %{})
    cache_enabled = Keyword.get(opts, :cache_enabled, true)

    cache_pid =
      case cache_enabled do
        true ->
          case ImageCache.start_link(cache_config) do
            {:ok, pid} -> pid
            {:error, {:already_started, pid}} -> pid
            {:error, _reason} -> nil
          end

        false ->
          nil
      end

    state = %{
      graphics: %{},
      active_graphics: nil,
      next_id: 1,
      config: Map.merge(default_config(), Enum.into(opts, %{})),
      graphics_support: graphics_support,
      preferred_protocol: determine_preferred_protocol(graphics_support),
      fallback_enabled: Keyword.get(opts, :fallback_enabled, true),
      cache_enabled: cache_enabled,
      cache_pid: cache_pid
    }

    Log.info(
      "GraphicsServer initialized with support: #{inspect(graphics_support)}"
    )

    Log.info("Image cache #{if cache_enabled, do: "enabled", else: "disabled"}")

    {:ok, state}
  end

  @impl true
  def handle_manager_call({:display_image, image_data, options}, _from, state) do
    with {:ok, protocol} <- select_protocol(options, state),
         {:ok, processed_options} <-
           prepare_display_options(options, protocol, state),
         {:ok, processed_image} <-
           process_image_with_cache(image_data, processed_options, state),
         {:ok, graphics_id} <-
           create_graphics_context(processed_options, state),
         {:ok, command} <-
           render_with_protocol(
             protocol,
             processed_image.data,
             processed_options
           ) do
      # Execute the display command (would normally write to terminal)
      Log.debug("Graphics command: #{inspect(command)}")

      new_state =
        update_graphics_state_with_image_info(
          graphics_id,
          command,
          processed_image,
          state
        )

      {:reply, {:ok, graphics_id}, new_state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call(
        {:display_images, images, shared_options},
        _from,
        state
      ) do
    results =
      Enum.map(images, fn
        {image_data, individual_options} ->
          merged_options = Map.merge(shared_options, individual_options)
          display_single_image(image_data, merged_options, state)

        image_data ->
          display_single_image(image_data, shared_options, state)
      end)

    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil ->
        {final_state, graphics_ids} =
          Enum.reduce(results, {state, []}, fn
            {:ok, graphics_id, new_state}, {_acc_state, ids} ->
              {new_state, [graphics_id | ids]}
          end)

        {:reply, {:ok, Enum.reverse(graphics_ids)}, final_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call(
        {:convert_and_display, image_data, target_format, options},
        _from,
        state
      ) do
    conversion_options =
      Map.merge(options, %{
        format: target_format,
        reprocess: true
      })

    case handle_call(
           {:display_image, image_data, conversion_options},
           nil,
           state
         ) do
      {:reply, result, new_state} -> {:reply, result, new_state}
    end
  end

  def handle_manager_call(
        {:optimize_and_display, image_data, options},
        _from,
        state
      ) do
    # Create terminal capability profiles based on current system
    terminal_profiles = create_terminal_profiles(state.graphics_support)

    case ImageProcessor.optimize_for_terminals(
           image_data,
           terminal_profiles,
           options
         ) do
      {:ok, optimized_variants} ->
        # Select the best variant for current terminal
        best_variant =
          select_best_variant(optimized_variants, state.graphics_support)

        # Display the optimized variant
        case handle_call(
               {:display_image, best_variant.data, options},
               nil,
               state
             ) do
          {:reply, {:ok, graphics_id}, new_state} ->
            # Store optimization info
            updated_state =
              store_optimization_info(
                graphics_id,
                optimized_variants,
                new_state
              )

            {:reply, {:ok, graphics_id}, updated_state}

          {:reply, error, new_state} ->
            {:reply, error, new_state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call({:get_image_info, graphics_id}, _from, state) do
    case Map.get(state.graphics, graphics_id) do
      nil -> {:reply, {:error, :graphics_not_found}, state}
      graphics_info -> {:reply, {:ok, graphics_info}, state}
    end
  end

  def handle_manager_call({:manage_cache, action, params}, _from, state) do
    case state.cache_enabled do
      false -> {:reply, {:error, :cache_disabled}, state}
      true -> handle_cache_management(action, params, state)
    end
  end

  def handle_manager_call(:get_graphics_info, _from, state) do
    info = %{
      supported_protocols: get_supported_protocols(state.graphics_support),
      preferred_protocol: state.preferred_protocol,
      terminal_info: %{
        type: state.graphics_support.terminal_type,
        capabilities: state.graphics_support.capabilities
      },
      capabilities: build_protocol_capabilities_map(state.graphics_support)
    }

    {:reply, info, state}
  end

  def handle_manager_call({:create_animation, frames, options}, _from, state) do
    case select_protocol(options, state) do
      {:ok, :kitty} ->
        # Use Kitty protocol for animation
        case KittyProtocol.create_animation(frames, options) do
          {:ok, commands} ->
            graphics_id = state.next_id

            new_state = %{
              state
              | graphics:
                  Map.put(state.graphics, graphics_id, %{
                    type: :animation,
                    protocol: :kitty,
                    commands: commands,
                    frame_count: length(frames)
                  }),
                next_id: graphics_id + 1
            }

            {:reply, {:ok, graphics_id}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:ok, _protocol} ->
        {:reply, {:error, :animation_not_supported}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call(
        {:set_preferred_protocol, protocol, fallback_enabled},
        _from,
        state
      ) do
    case validate_protocol_choice(protocol, state.graphics_support) do
      :ok ->
        new_state = %{
          state
          | preferred_protocol: protocol,
            fallback_enabled: fallback_enabled
        }

        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call(
        {:update_graphics_properties, graphics_id, properties},
        _from,
        state
      ) do
    case Map.get(state.graphics, graphics_id) do
      nil ->
        {:reply, {:error, :graphics_not_found}, state}

      graphics_info ->
        # Update properties in the graphics info
        updated_info =
          Map.merge(graphics_info, %{
            properties: properties,
            updated_at: System.system_time(:millisecond)
          })

        # Apply the property changes based on protocol
        case apply_property_updates(
               graphics_id,
               properties,
               graphics_info.protocol
             ) do
          :ok ->
            new_graphics = Map.put(state.graphics, graphics_id, updated_info)
            {:reply, :ok, %{state | graphics: new_graphics}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_manager_call({:create_graphics, config}, _from, state) do
    graphics_id = state.next_id

    graphics_state = %{
      id: graphics_id,
      config: Map.merge(default_graphics_config(), config),
      buffer: <<>>,
      back_buffer: <<>>,
      last_render: nil,
      created_at: System.system_time(:millisecond)
    }

    new_state = %{
      state
      | graphics: Map.put(state.graphics, graphics_id, graphics_state),
        next_id: graphics_id + 1
    }

    # If this is the first graphics context, make it active
    new_state = set_active_if_first(new_state, graphics_id)

    {:reply, {:ok, graphics_id}, new_state}
  end

  def handle_manager_call(:get_graphics, _from, state) do
    {:reply, Map.keys(state.graphics), state}
  end

  def handle_manager_call(:get_active_graphics, _from, state) do
    case state.active_graphics do
      nil -> {:reply, {:error, :no_active_graphics}, state}
      graphics_id -> {:reply, {:ok, graphics_id}, state}
    end
  end

  def handle_manager_call({:set_active_graphics, graphics_id}, _from, state) do
    case Map.get(state.graphics, graphics_id) do
      nil ->
        {:reply, {:error, :graphics_not_found}, state}

      _graphics ->
        new_state = %{state | active_graphics: graphics_id}
        {:reply, :ok, new_state}
    end
  end

  def handle_manager_call({:get_graphics_state, graphics_id}, _from, state) do
    case Map.get(state.graphics, graphics_id) do
      nil -> {:reply, {:error, :graphics_not_found}, state}
      graphics_state -> {:reply, {:ok, graphics_state}, state}
    end
  end

  def handle_manager_call(
        {:update_graphics_config, graphics_id, config},
        _from,
        state
      ) do
    case Map.get(state.graphics, graphics_id) do
      nil ->
        {:reply, {:error, :graphics_not_found}, state}

      graphics_state ->
        new_config = Map.merge(graphics_state.config, config)
        new_graphics_state = %{graphics_state | config: new_config}

        new_state = %{
          state
          | graphics: Map.put(state.graphics, graphics_id, new_graphics_state)
        }

        {:reply, :ok, new_state}
    end
  end

  def handle_manager_call({:render_graphics, graphics_id, data}, _from, state) do
    case Map.get(state.graphics, graphics_id) do
      nil ->
        {:reply, {:error, :graphics_not_found}, state}

      graphics_state ->
        # Only update if data has changed
        update_graphics_buffer(data, graphics_state, graphics_id, state)
    end
  end

  def handle_manager_call({:swap_buffers, graphics_id}, _from, state) do
    case Map.get(state.graphics, graphics_id) do
      nil ->
        {:reply, {:error, :graphics_not_found}, state}

      graphics_state ->
        # Swap front and back buffers
        new_graphics_state = %{
          graphics_state
          | buffer: graphics_state.back_buffer,
            back_buffer: graphics_state.buffer
        }

        new_state = %{
          state
          | graphics: Map.put(state.graphics, graphics_id, new_graphics_state)
        }

        {:reply, :ok, new_state}
    end
  end

  def handle_manager_call({:clear_graphics, graphics_id}, _from, state) do
    case Map.get(state.graphics, graphics_id) do
      nil ->
        {:reply, {:error, :graphics_not_found}, state}

      graphics_state ->
        new_graphics_state = %{graphics_state | buffer: <<>>}

        new_state = %{
          state
          | graphics: Map.put(state.graphics, graphics_id, new_graphics_state)
        }

        {:reply, :ok, new_state}
    end
  end

  def handle_manager_call({:close_graphics, graphics_id}, _from, state) do
    case Map.get(state.graphics, graphics_id) do
      nil ->
        {:reply, {:error, :graphics_not_found}, state}

      _graphics ->
        # Remove graphics context
        new_graphics = Map.delete(state.graphics, graphics_id)

        # Update active graphics if needed
        new_active_graphics =
          update_active_graphics_after_close(
            state.active_graphics,
            graphics_id,
            new_graphics
          )

        new_state = %{
          state
          | graphics: new_graphics,
            active_graphics: new_active_graphics
        }

        {:reply, :ok, new_state}
    end
  end

  def handle_manager_call({:update_config, config}, _from, state) do
    new_config = Map.merge(state.config, config)
    new_state = %{state | config: new_config}
    {:reply, :ok, new_state}
  end

  def handle_manager_call(:cleanup, _from, state) do
    # Clean up all graphics contexts
    {:reply, :ok, %{state | graphics: %{}, active_graphics: nil}}
  end

  # Private Functions
  defp get_new_buffer(back_buffer, data) do
    case back_buffer do
      nil -> data
      buffer -> buffer
    end
  end

  defp update_active_graphics_after_close(
         active_graphics,
         closed_graphics_id,
         new_graphics
       ) do
    handle_graphics_close_update(
      active_graphics == closed_graphics_id,
      active_graphics,
      new_graphics
    )
  end

  defp default_config do
    %{
      max_graphics: 10,
      default_width: 800,
      default_height: 600,
      default_format: :rgba,
      default_compression: :none,
      default_quality: 90
    }
  end

  defp default_graphics_config do
    %{
      width: 800,
      height: 600,
      format: :rgba,
      compression: :none,
      quality: 90
    }
  end

  defp update_graphics_buffer(data, graphics_state, graphics_id, state) do
    handle_buffer_update(
      data == graphics_state.buffer,
      data,
      graphics_state,
      graphics_id,
      state
    )
  end

  defp handle_buffer_update(true, _data, _graphics_state, _graphics_id, state) do
    {:reply, :ok, state}
  end

  defp handle_buffer_update(false, data, graphics_state, graphics_id, state) do
    # Use double buffering for smooth rendering
    new_buffer = get_new_buffer(graphics_state.back_buffer, data)

    new_graphics_state = %{
      graphics_state
      | buffer: data,
        back_buffer: new_buffer,
        last_render: System.system_time(:millisecond)
    }

    new_state = %{
      state
      | graphics: Map.put(state.graphics, graphics_id, new_graphics_state)
    }

    {:reply, :ok, new_state}
  end

  defp handle_graphics_close_update(true, _active_graphics, new_graphics) do
    case Map.keys(new_graphics) do
      [] -> nil
      [first_graphics | _] -> first_graphics
    end
  end

  defp handle_graphics_close_update(false, active_graphics, _new_graphics) do
    active_graphics
  end

  defp set_active_if_first(%{active_graphics: nil} = state, graphics_id) do
    %{state | active_graphics: graphics_id}
  end

  defp set_active_if_first(state, _graphics_id), do: state

  # New helper functions for unified graphics API

  defp determine_preferred_protocol(graphics_support) do
    cond do
      graphics_support.kitty_graphics -> :kitty
      graphics_support.iterm2_graphics -> :iterm2
      graphics_support.sixel_graphics -> :sixel
      true -> :fallback
    end
  end

  defp select_protocol(options, state) do
    requested_protocol = Map.get(options, :protocol, state.preferred_protocol)

    case {requested_protocol, protocol_supported?(requested_protocol, state)} do
      {:auto, _} ->
        {:ok, state.preferred_protocol}

      {protocol, true} ->
        {:ok, protocol}

      {_protocol, false} when state.fallback_enabled ->
        {:ok, state.preferred_protocol}

      {protocol, false} ->
        {:error, {:protocol_not_supported, protocol}}
    end
  end

  defp protocol_supported?(protocol, state) do
    case protocol do
      :kitty -> state.graphics_support.kitty_graphics
      :iterm2 -> state.graphics_support.iterm2_graphics
      :sixel -> state.graphics_support.sixel_graphics
      :fallback -> true
      :auto -> true
      _ -> false
    end
  end

  defp prepare_display_options(options, protocol, state) do
    # Add protocol-specific option processing
    base_options =
      Map.merge(
        %{
          width: 800,
          height: 600,
          format: :png,
          scale: 1.0
        },
        options
      )

    protocol_options = Map.put(base_options, :protocol, protocol)

    # Add terminal capability constraints
    capabilities = Map.get(state.graphics_support.capabilities, protocol, %{})

    constrained_options =
      apply_capability_constraints(protocol_options, capabilities)

    {:ok, constrained_options}
  end

  defp apply_capability_constraints(options, capabilities) do
    options
    |> constrain_image_size(capabilities)
    |> constrain_dimensions(capabilities)
  end

  defp constrain_image_size(options, capabilities) do
    max_size = Map.get(capabilities, :max_image_size, 0)

    case max_size do
      0 -> options
      _ -> Map.put(options, :max_size, max_size)
    end
  end

  defp constrain_dimensions(options, capabilities) do
    max_width = Map.get(capabilities, :max_image_width, 10_000)
    max_height = Map.get(capabilities, :max_image_height, 10_000)

    options
    |> Map.update(:width, 800, &min(&1, max_width))
    |> Map.update(:height, 600, &min(&1, max_height))
  end

  defp create_graphics_context(_options, state) do
    graphics_id = state.next_id
    {:ok, graphics_id}
  end

  defp render_with_protocol(:kitty, image_data, options) do
    KittyProtocol.transmit_image(image_data, options)
  end

  defp render_with_protocol(:sixel, image_data, options) do
    # Convert to sixel format using existing implementation
    case SixelGraphics.encode(%SixelGraphics{
           width: Map.get(options, :width, 800),
           height: Map.get(options, :height, 600),
           data: image_data
         }) do
      "" -> {:error, :sixel_encoding_failed}
      encoded -> {:ok, encoded}
    end
  end

  defp render_with_protocol(:iterm2, image_data, options) do
    # iTerm2 inline image protocol implementation
    encoded_data = Base.encode64(image_data)
    width = Map.get(options, :width, 800)
    height = Map.get(options, :height, 600)

    # iTerm2 inline image escape sequence
    command =
      "\033]1337;File=inline=1;width=#{width};height=#{height}:#{encoded_data}\007"

    {:ok, command}
  end

  defp render_with_protocol(:fallback, _image_data, _options) do
    # ASCII art fallback
    ascii_art = """
    [IMAGE: ASCII representation not implemented]
    +------------------+
    |   ████████████   |
    |   ██        ██   |
    |   ██  ████  ██   |
    |   ██  ████  ██   |
    |   ██        ██   |
    |   ████████████   |
    +------------------+
    """

    {:ok, ascii_art}
  end

  defp render_with_protocol(protocol, _image_data, _options) do
    {:error, {:unsupported_protocol, protocol}}
  end

  defp get_supported_protocols(graphics_support) do
    []
    |> add_if_supported(:kitty, graphics_support.kitty_graphics)
    |> add_if_supported(:iterm2, graphics_support.iterm2_graphics)
    |> add_if_supported(:sixel, graphics_support.sixel_graphics)
    |> add_if_supported(:fallback, true)
  end

  defp add_if_supported(protocols, protocol, true), do: [protocol | protocols]
  defp add_if_supported(protocols, _protocol, false), do: protocols

  defp build_protocol_capabilities_map(graphics_support) do
    %{}
    |> add_protocol_capabilities(
      :kitty,
      graphics_support.kitty_graphics,
      graphics_support.capabilities
    )
    |> add_protocol_capabilities(
      :iterm2,
      graphics_support.iterm2_graphics,
      graphics_support.capabilities
    )
    |> add_protocol_capabilities(
      :sixel,
      graphics_support.sixel_graphics,
      graphics_support.capabilities
    )
  end

  defp add_protocol_capabilities(map, _protocol, false, _capabilities), do: map

  defp add_protocol_capabilities(map, protocol, true, capabilities) do
    Map.put(map, protocol, Map.get(capabilities, protocol, %{}))
  end

  defp validate_protocol_choice(:auto, _graphics_support), do: :ok

  defp validate_protocol_choice(protocol, graphics_support) do
    case protocol_supported?(protocol, %{graphics_support: graphics_support}) do
      true -> :ok
      false -> {:error, {:protocol_not_supported, protocol}}
    end
  end

  # New helper functions for advanced image processing

  defp process_image_with_cache(image_data, options, state) do
    case state.cache_enabled do
      false ->
        # Process image directly
        ImageProcessor.process_image(image_data, options)

      true ->
        # Check cache first
        cache_key = ImageCache.generate_key(image_data, options)

        case ImageCache.get(cache_key) do
          {:ok, cached_data} ->
            # Return cached processed image
            {:ok,
             %{
               data: cached_data,
               format: Map.get(options, :format, :png),
               width: Map.get(options, :width, 800),
               height: Map.get(options, :height, 600),
               metadata: %{cached: true}
             }}

          {:error, _} ->
            # Process image and cache result
            case ImageProcessor.process_image(image_data, options) do
              {:ok, processed_image} ->
                # Cache the processed result
                _ =
                  ImageCache.put(
                    cache_key,
                    processed_image.data,
                    processed_image.metadata
                  )

                {:ok, processed_image}

              error ->
                error
            end
        end
    end
  end

  defp display_single_image(image_data, options, state) do
    case handle_call({:display_image, image_data, options}, nil, state) do
      {:reply, {:ok, graphics_id}, new_state} -> {:ok, graphics_id, new_state}
      {:reply, {:error, reason}, _state} -> {:error, reason}
    end
  end

  defp update_graphics_state_with_image_info(
         graphics_id,
         command,
         processed_image,
         state
       ) do
    graphics_info = %{
      id: graphics_id,
      command: command,
      protocol: state.preferred_protocol,
      timestamp: System.system_time(:millisecond),
      image_info: %{
        format: processed_image.format,
        width: processed_image.width,
        height: processed_image.height,
        size: byte_size(processed_image.data),
        metadata: processed_image.metadata
      }
    }

    %{
      state
      | graphics: Map.put(state.graphics, graphics_id, graphics_info),
        next_id: graphics_id + 1
    }
  end

  defp create_terminal_profiles(graphics_support) do
    base_profile = %{
      name: :current_terminal,
      max_colors: 256,
      dither_method: :floyd_steinberg
    }

    # Create variants for different capability levels
    profiles = [
      base_profile,
      %{name: :high_color, max_colors: 256, dither_method: :none},
      %{name: :limited_color, max_colors: 64, dither_method: :floyd_steinberg},
      %{name: :monochrome, max_colors: 2, dither_method: :floyd_steinberg}
    ]

    # Add terminal-specific optimizations
    case graphics_support.terminal_type do
      :kitty ->
        # True color
        [Map.put(base_profile, :max_colors, 16_777_216) | profiles]

      :iterm2 ->
        [Map.put(base_profile, :max_colors, 256) | profiles]

      _ ->
        profiles
    end
  end

  defp select_best_variant(optimized_variants, graphics_support) do
    # Select the best variant based on terminal capabilities
    preferred_order =
      case graphics_support.terminal_type do
        :kitty -> [:high_color, :current_terminal, :limited_color, :monochrome]
        :iterm2 -> [:current_terminal, :high_color, :limited_color, :monochrome]
        _ -> [:current_terminal, :limited_color, :monochrome]
      end

    Enum.find_value(preferred_order, fn profile_name ->
      Map.get(optimized_variants, profile_name)
    end) || Map.values(optimized_variants) |> List.first()
  end

  defp store_optimization_info(graphics_id, optimized_variants, state) do
    case Map.get(state.graphics, graphics_id) do
      nil ->
        state

      graphics_info ->
        updated_info =
          Map.put(
            graphics_info,
            :optimization_variants,
            Map.keys(optimized_variants)
          )

        updated_graphics = Map.put(state.graphics, graphics_id, updated_info)
        %{state | graphics: updated_graphics}
    end
  end

  defp handle_cache_management(:get_stats, _params, state) do
    case ImageCache.get_stats() do
      stats -> {:reply, {:ok, stats}, state}
    end
  end

  defp handle_cache_management(:clear, _params, state) do
    case ImageCache.clear() do
      :ok -> {:reply, :ok, state}
    end
  end

  defp handle_cache_management(:preload, %{images: images}, state) do
    case ImageCache.preload(images) do
      :ok -> {:reply, :ok, state}
    end
  end

  defp handle_cache_management(_action, _params, state) do
    {:reply, {:error, :invalid_cache_action}, state}
  end

  defp apply_property_updates(graphics_id, properties, protocol) do
    case protocol do
      :kitty ->
        # Apply property updates using Kitty protocol
        apply_kitty_property_updates(graphics_id, properties)

      :iterm2 ->
        # iTerm2 doesn't support dynamic property updates
        {:error, :property_updates_not_supported}

      :sixel ->
        # Sixel doesn't support dynamic property updates
        {:error, :property_updates_not_supported}

      _ ->
        # Fallback - just acknowledge the update
        :ok
    end
  end

  defp apply_kitty_property_updates(graphics_id, properties) do
    # Build Kitty protocol commands for property updates
    commands =
      Enum.reduce(properties, [], fn {property, value}, acc ->
        case build_kitty_property_command(graphics_id, property, value) do
          {:ok, command} -> [command | acc]
          {:error, _reason} -> acc
        end
      end)

    # Send commands to terminal
    case commands do
      [] ->
        :ok

      _ ->
        # For now, just return ok - in a real implementation,
        # these would be sent to the terminal
        :ok
    end
  end

  defp build_kitty_property_command(graphics_id, property, value) do
    case property do
      :opacity when is_number(value) and value >= 0.0 and value <= 1.0 ->
        # Kitty protocol command for opacity
        alpha = round(value * 255)
        {:ok, "\e_Ga=p,i=#{graphics_id},O=#{alpha}\e\\"}

      :position
      when is_map(value) and is_number(value.x) and is_number(value.y) ->
        # Kitty protocol command for positioning
        {:ok, "\e_Ga=p,i=#{graphics_id},X=#{value.x},Y=#{value.y}\e\\"}

      :scale when is_number(value) and value > 0 ->
        # Scale transformation
        scale_percent = round(value * 100)
        {:ok, "\e_Ga=p,i=#{graphics_id},s=#{scale_percent}\e\\"}

      _ ->
        {:error, :unsupported_property}
    end
  end
end
