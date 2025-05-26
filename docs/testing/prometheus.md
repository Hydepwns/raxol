# Prometheus Integration for Raxol

Raxol exposes terminal and system metrics for Prometheus at the `/metrics` endpoint (default: `http://localhost:4000/metrics`).

## Example Prometheus Scrape Config

Add this to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: "raxol"
    static_configs:
      - targets: ["localhost:4000"]
    metrics_path: /metrics
```

## Exposed Metrics

- `raxol_terminal_scroll_event_delta` (histogram): Scroll delta per event, tagged by direction
- `raxol_terminal_paste_event_length` (summary): Length of pasted text per event
- `raxol_terminal_focus_changed_total` (counter): Terminal focus events
- `raxol_terminal_resized_total` (counter): Terminal resize events
- `raxol_terminal_mode_changed_total` (counter): Terminal mode changes (tagged by mode)
- `raxol_terminal_clipboard_event_total` (counter): Clipboard events
- `raxol_terminal_selection_changed_total` (counter): Selection events
- `raxol_terminal_paste_event_total` (counter): Paste events
- `raxol_terminal_cursor_event_total` (counter): Cursor events

## Testing and Verification

- Visit `http://localhost:4000/metrics` in your browser to see live metrics.
- Run the test suite (`mix test`) to verify telemetry event emission (see `test/raxol/terminal/manager_test.exs`).
- Use `curl` to fetch metrics:
  ```sh
  curl http://localhost:4000/metrics
  ```

## Extending Metrics

You can add or customize metrics in `lib/raxol/terminal/telemetry_prometheus.ex` by editing the `metrics/0` function.

For more details, see the [TelemetryMetricsPrometheus documentation](https://hexdocs.pm/telemetry_metrics_prometheus/).
