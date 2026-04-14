# `Raxol.Sensor.Fusion.NxBackend`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/sensor/fusion/nx_backend.ex#L2)

Nx-accelerated sensor fusion operations.

Replaces the pure-Elixir weighted averaging in `Sensor.Fusion`
with vectorized Nx tensor operations. Only compiled when Nx is
available as a dependency.

# `weighted_average`

```elixir
@spec weighted_average([map()], [number()]) :: map()
```

Compute weighted average of sensor readings using Nx tensors.

Takes a list of value maps and a corresponding list of quality
weights. Returns a single map of weighted-average values per key.

Vectorized: builds a [n_readings, n_keys] matrix and a [n_readings]
weight vector, then computes the dot product in one pass.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
