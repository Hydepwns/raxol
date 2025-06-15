defmodule Raxol.Animation.Animation do
  @moduledoc """
  Delegates animation API calls to Raxol.Animation.Framework for test and compatibility purposes.
  """

  defdelegate stop(), to: Raxol.Animation.Framework
  defdelegate create_animation(name, params), to: Raxol.Animation.Framework
  defdelegate start_animation(name, id), to: Raxol.Animation.Framework
  defdelegate start_animation(name, id, opts), to: Raxol.Animation.Framework
  defdelegate apply_animations_to_state(state), to: Raxol.Animation.Framework
  defdelegate get_current_value(name, id), to: Raxol.Animation.Framework

  def init(opts \\ %{}, user_preferences_pid \\ nil) do
    Raxol.Animation.Framework.init(opts, user_preferences_pid)
  end

  def should_reduce_motion?(user_preferences_pid \\ nil) do
    Raxol.Animation.Framework.should_reduce_motion?(user_preferences_pid)
  end
end
