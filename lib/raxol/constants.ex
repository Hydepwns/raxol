defmodule Raxol.Constants do
  @moduledoc """
  Centralized defaults for the Raxol framework.

  Provides canonical default values for terminal dimensions, rendering intervals,
  network ports, and buffer sizes. Use these instead of hardcoding magic numbers.

  Terminal dimension, timeout, and interval defaults are delegated to
  `Raxol.Core.Defaults` (in raxol_core) so extracted packages can share them.
  """

  # Rendering (60fps)
  @default_frame_interval_ms 16

  # SSH
  @default_ssh_port 2222

  # -- Terminal (delegated) --
  defdelegate default_terminal_width,
    to: Raxol.Core.Defaults,
    as: :terminal_width

  defdelegate default_terminal_height,
    to: Raxol.Core.Defaults,
    as: :terminal_height

  defdelegate default_terminal_dimensions,
    to: Raxol.Core.Defaults,
    as: :terminal_dimensions

  defdelegate default_scrollback_size,
    to: Raxol.Core.Defaults,
    as: :scrollback_limit

  # -- Timeouts (delegated) --
  defdelegate default_timeout_ms, to: Raxol.Core.Defaults, as: :timeout_ms

  defdelegate default_shutdown_timeout_ms,
    to: Raxol.Core.Defaults,
    as: :shutdown_timeout_ms

  defdelegate default_health_check_interval_ms,
    to: Raxol.Core.Defaults,
    as: :health_check_interval_ms

  defdelegate default_idle_timeout_ms,
    to: Raxol.Core.Defaults,
    as: :idle_timeout_ms

  defdelegate default_cleanup_interval_ms,
    to: Raxol.Core.Defaults,
    as: :cleanup_interval_ms

  defdelegate default_cooldown_ms, to: Raxol.Core.Defaults, as: :cooldown_ms

  # -- Animation & UI (delegated) --
  defdelegate default_animation_duration_ms,
    to: Raxol.Core.Defaults,
    as: :animation_duration_ms

  defdelegate default_debounce_ms, to: Raxol.Core.Defaults, as: :debounce_ms

  defdelegate default_sync_interval_ms,
    to: Raxol.Core.Defaults,
    as: :sync_interval_ms

  defdelegate default_monitor_interval_ms,
    to: Raxol.Core.Defaults,
    as: :monitor_interval_ms

  # -- Circuit Breaker (delegated) --
  defdelegate default_cb_open_timeout_ms,
    to: Raxol.Core.Defaults,
    as: :cb_open_timeout_ms

  defdelegate default_cb_half_open_timeout_ms,
    to: Raxol.Core.Defaults,
    as: :cb_half_open_timeout_ms

  defdelegate default_cb_reset_timeout_ms,
    to: Raxol.Core.Defaults,
    as: :cb_reset_timeout_ms

  # -- Cache & Limits (delegated) --
  defdelegate default_history_limit, to: Raxol.Core.Defaults, as: :history_limit

  defdelegate default_cache_ttl_seconds,
    to: Raxol.Core.Defaults,
    as: :cache_ttl_seconds

  # -- Local constants --
  def default_frame_interval_ms, do: @default_frame_interval_ms
  def default_ssh_port, do: @default_ssh_port
end
