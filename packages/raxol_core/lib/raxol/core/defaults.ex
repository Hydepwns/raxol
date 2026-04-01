defmodule Raxol.Core.Defaults do
  @moduledoc """
  Canonical default values for the Raxol framework.

  These compile-time constants eliminate magic numbers across packages.
  All packages depend on raxol_core, so these are universally accessible.
  """

  # -- Terminal --
  @default_terminal_width 80
  @default_terminal_height 24
  @default_scrollback_limit 1000

  def terminal_width, do: @default_terminal_width
  def terminal_height, do: @default_terminal_height
  def terminal_dimensions, do: {@default_terminal_width, @default_terminal_height}
  def scrollback_limit, do: @default_scrollback_limit

  # -- Timeouts (milliseconds) --
  @default_timeout_ms 5_000
  @default_shutdown_timeout_ms 5_000
  @default_health_check_interval_ms 30_000
  @default_idle_timeout_ms 60_000
  @default_cleanup_interval_ms 60_000
  @default_cooldown_ms 300_000

  def timeout_ms, do: @default_timeout_ms
  def shutdown_timeout_ms, do: @default_shutdown_timeout_ms
  def health_check_interval_ms, do: @default_health_check_interval_ms
  def idle_timeout_ms, do: @default_idle_timeout_ms
  def cleanup_interval_ms, do: @default_cleanup_interval_ms
  def cooldown_ms, do: @default_cooldown_ms

  # -- Animation & UI (milliseconds) --
  @default_animation_duration_ms 300
  @default_debounce_ms 300
  @default_sync_interval_ms 500
  @default_monitor_interval_ms 1_000

  def animation_duration_ms, do: @default_animation_duration_ms
  def debounce_ms, do: @default_debounce_ms
  def sync_interval_ms, do: @default_sync_interval_ms
  def monitor_interval_ms, do: @default_monitor_interval_ms

  # -- Circuit Breaker (milliseconds) --
  @default_cb_open_timeout_ms 30_000
  @default_cb_half_open_timeout_ms 15_000
  @default_cb_reset_timeout_ms 120_000

  def cb_open_timeout_ms, do: @default_cb_open_timeout_ms
  def cb_half_open_timeout_ms, do: @default_cb_half_open_timeout_ms
  def cb_reset_timeout_ms, do: @default_cb_reset_timeout_ms

  # -- Cache & Limits --
  @default_history_limit 1_000
  @default_cache_ttl_seconds 3_600

  def history_limit, do: @default_history_limit
  def cache_ttl_seconds, do: @default_cache_ttl_seconds
end
