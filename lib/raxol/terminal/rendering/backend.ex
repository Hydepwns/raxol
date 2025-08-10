defmodule Raxol.Terminal.Rendering.Backend do
  @moduledoc """
  Behaviour definition for terminal rendering backends.

  This module defines the interface that all rendering backends must implement,
  including GPU-accelerated backends (OpenGL, Metal, Vulkan) and software rendering.
  """

  @type surface :: %{
          id: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          format: atom(),
          backend: atom()
        }

  @type terminal_buffer :: %{
          lines: list(),
          width: pos_integer(),
          height: pos_integer(),
          cursor: map(),
          colors: map()
        }

  @type render_opts :: [
          viewport: {integer(), integer(), pos_integer(), pos_integer()},
          scale: float(),
          vsync: boolean(),
          effects: list()
        ]

  @type effect_type ::
          :blur | :glow | :scanlines | :chromatic_aberration | :vignette

  @type stats :: %{
          fps: float(),
          frame_time: float(),
          draw_calls: non_neg_integer(),
          vertices: non_neg_integer(),
          memory_usage: non_neg_integer()
        }

  @doc """
  Initializes the rendering backend with the given configuration.
  """
  @callback init(config :: map()) ::
              {:ok, state :: term()} | {:error, reason :: term()}

  @doc """
  Creates a rendering surface with the specified options.
  """
  @callback create_surface(state :: term(), opts :: keyword()) ::
              {:ok, surface(), new_state :: term()} | {:error, reason :: term()}

  @doc """
  Destroys a rendering surface and releases its resources.
  """
  @callback destroy_surface(state :: term(), surface :: surface()) ::
              {:ok, new_state :: term()} | {:error, reason :: term()}

  @doc """
  Renders terminal content to the specified surface.
  """
  @callback render(
              state :: term(),
              surface :: surface(),
              buffer :: terminal_buffer(),
              opts :: render_opts()
            ) ::
              {:ok, new_state :: term()} | {:error, reason :: term()}

  @doc """
  Enables a visual effect on the rendering backend.
  """
  @callback enable_effect(
              state :: term(),
              effect :: effect_type(),
              params :: keyword()
            ) ::
              {:ok, new_state :: term()} | {:error, reason :: term()}

  @doc """
  Disables a visual effect.
  """
  @callback disable_effect(state :: term(), effect :: effect_type()) ::
              {:ok, new_state :: term()} | {:error, reason :: term()}

  @doc """
  Gets rendering performance statistics.
  """
  @callback get_stats(state :: term()) :: {:ok, stats(), new_state :: term()}

  @doc """
  Updates the backend configuration.
  """
  @callback update_config(state :: term(), config :: map()) ::
              {:ok, new_state :: term()} | {:error, reason :: term()}

  @doc """
  Checks if the backend is available on the current system.
  """
  @callback available?() :: boolean()

  @doc """
  Gets the backend's capabilities and supported features.
  """
  @callback capabilities() :: %{
              max_texture_size: pos_integer(),
              supports_shaders: boolean(),
              supports_effects: [effect_type()],
              hardware_accelerated: boolean()
            }
end
