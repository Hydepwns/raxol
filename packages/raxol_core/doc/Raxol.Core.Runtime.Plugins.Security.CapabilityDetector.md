# `Raxol.Core.Runtime.Plugins.Security.CapabilityDetector`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/security/capability_detector.ex#L1)

High-level capability detection for plugins.

This module provides a simple interface to detect what capabilities a plugin
requires and whether those capabilities are permitted by the current security policy.

## Usage

    # Detect all capabilities
    capabilities = CapabilityDetector.detect_capabilities(MyPlugin)
    # => %{
    #   file_access: true,
    #   network_access: false,
    #   code_injection: false,
    #   system_commands: false
    # }

    # Check against policy
    policy = %{allow_file_access: false, allow_network: true}
    case CapabilityDetector.validate_against_policy(MyPlugin, policy) do
      :ok -> # Plugin is safe according to policy
      {:error, :file_access_denied} -> # Plugin requires file access but policy denies it
    end

# `capabilities`

```elixir
@type capabilities() :: %{
  file_access: boolean(),
  network_access: boolean(),
  code_injection: boolean(),
  system_commands: boolean()
}
```

# `capability`

```elixir
@type capability() ::
  :file_access | :network_access | :code_injection | :system_commands
```

# `policy`

```elixir
@type policy() :: %{
  allow_file_access: boolean(),
  allow_network_access: boolean(),
  allow_code_injection: boolean(),
  allow_system_commands: boolean()
}
```

# `capability_report`

```elixir
@spec capability_report(module()) :: String.t()
```

Generates a human-readable report of a module's capabilities.

# `create_policy`

```elixir
@spec create_policy([capability()]) :: policy()
```

Creates a custom policy allowing only specified capabilities.

# `default_policy`

```elixir
@spec default_policy() :: %{
  allow_file_access: false,
  allow_network_access: false,
  allow_code_injection: false,
  allow_system_commands: false
}
```

Returns the default security policy.

By default, all sensitive capabilities are denied.

# `detect_capabilities`

```elixir
@spec detect_capabilities(module()) ::
  Raxol.Core.Runtime.Plugins.Security.BeamAnalyzer.analysis_result()
```

Detects all capabilities of a module.

Returns a map indicating which security-sensitive capabilities the module has.

# `permissive_policy`

```elixir
@spec permissive_policy() :: %{
  allow_file_access: true,
  allow_network_access: true,
  allow_code_injection: true,
  allow_system_commands: true
}
```

Returns a permissive policy that allows all capabilities.

Use with caution - only for trusted plugins.

# `validate_against_policy`

```elixir
@spec validate_against_policy(module(), policy()) :: :ok | {:error, atom()}
```

Validates a module's capabilities against a security policy.

Returns `:ok` if the module's capabilities are within policy bounds,
or an error tuple describing the violation.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
