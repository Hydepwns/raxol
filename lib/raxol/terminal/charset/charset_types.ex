defmodule Raxol.Terminal.Charset.Types do
  @moduledoc """
  Defines types used across the charset modules.
  """

  @type g_set :: :g0 | :g1 | :g2 | :g3
  @type charset ::
          :us_ascii | :dec_supplementary | :dec_special | :dec_technical
  @type char_map :: %{non_neg_integer() => String.t()}
  @type t :: %Raxol.Terminal.Charset.Manager{
          g_sets: %{g_set() => charset()},
          current_g_set: g_set(),
          single_shift: g_set() | nil,
          charsets: %{charset() => (-> char_map())}
        }
end
