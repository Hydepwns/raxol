# `Raxol.Core.Runtime.Plugins.MissionProfile`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/mission_profile.ex#L1)

Named set of plugins with configuration overrides.

A mission profile is analogous to a Brewfile or Docker Compose file
for plugins -- it declares which plugins to load and how to configure them.

Profiles support inheritance (a child profile inherits its parent's plugins)
and diff-based hot-swapping (switching profiles only loads/unloads the delta).

# `t`

```elixir
@type t() :: %Raxol.Core.Runtime.Plugins.MissionProfile{
  description: String.t(),
  id: atom(),
  inherits: atom() | nil,
  name: String.t(),
  plugins: [{atom(), map()}]
}
```

# `activate`

```elixir
@spec activate(t(), (atom() -&gt;
                 {:ok, Raxol.Core.Runtime.Plugins.Manifest.t()}
                 | {:error, term()})) ::
  {:ok, [atom()]} | {:error, term()}
```

Activates a profile: resolves dependencies and loads plugins in order.

`manifest_lookup` is a function `(atom() -> {:ok, Manifest.t()} | {:error, term()})`
that retrieves the manifest for a given plugin id.

# `deactivate`

```elixir
@spec deactivate(t()) :: :ok
```

Deactivates a profile by unloading all its plugins.

# `diff`

```elixir
@spec diff(t(), t()) :: %{add: [atom()], remove: [atom()], reconfigure: [atom()]}
```

Computes the diff between two profiles.

Returns a map with `:add`, `:remove`, and `:reconfigure` keys.

# `init`

```elixir
@spec init() :: :ok
```

Initializes the profiles ETS table. Call once at startup.

# `load`

```elixir
@spec load(atom()) :: {:ok, t()} | {:error, :not_found}
```

Loads a registered profile by id.

# `register`

```elixir
@spec register(t()) :: :ok
```

Registers a profile so it can be loaded by id.

# `resolve_plugins`

```elixir
@spec resolve_plugins(t()) :: [{atom(), map()}]
```

Returns the fully resolved plugin list, including inherited plugins.

Child plugins override parent plugins with the same id.

# `switch`

```elixir
@spec switch(t(), t(), (atom() -&gt;
                    {:ok, Raxol.Core.Runtime.Plugins.Manifest.t()}
                    | {:error, term()})) ::
  {:ok, [atom()]} | {:error, term()}
```

Switches from one profile to another, only loading/unloading the delta.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
