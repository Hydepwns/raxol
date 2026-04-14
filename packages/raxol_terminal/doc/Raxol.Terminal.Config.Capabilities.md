# `Raxol.Terminal.Config.Capabilities`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/config/capabilities.ex#L2)

Terminal capability detection and management.

Provides functionality to detect and determine terminal capabilities
such as color support, unicode support, etc.

# `apply_capabilities`

Merges detected capabilities with configuration using a specific adapter.

Takes a terminal configuration and enhances it with detected capabilities
where those capabilities aren't already explicitly configured.

## Parameters
* `config` - The existing configuration
* `adapter_module` - The module implementing `EnvironmentAdapterBehaviour`.

## Returns

The configuration enhanced with detected capabilities.

# `detect_capabilities`

Detects terminal capabilities based on the environment using a specific adapter.

This examines environment variables, terminal responses, and other indicators
to determine capabilities of the current terminal.

## Parameters
* `adapter_module` - The module implementing `EnvironmentAdapterBehaviour`.

## Returns

A map of detected capabilities.

# `optimized_config`

Creates an optimized configuration based on detected capabilities using the default adapter.

This generates a configuration that's optimized for the current terminal
environment, balancing features and performance.

## Returns

An optimized configuration for the current terminal.

# `optimized_config`

Creates an optimized configuration based on detected capabilities using a specific adapter.

## Parameters
* `adapter_module` - The module implementing `EnvironmentAdapterBehaviour`.

## Returns

An optimized configuration for the current terminal.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
