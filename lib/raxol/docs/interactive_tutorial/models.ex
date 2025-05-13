defmodule Raxol.Docs.InteractiveTutorial.Models do
  @moduledoc """
  Defines the core data structures for the interactive tutorial system.
  """

  @type tutorial_id :: String.t()
  @type step_id :: String.t()

  defmodule Step do
    @moduledoc """
    Represents a single step in a tutorial.
    """
    defstruct [
      :id,
      :title,
      :content,
      :example_code,
      :exercise,
      :validation,
      :hints,
      :next_steps,
      :interactive_elements
    ]

    @type t :: %__MODULE__{
            id: Raxol.Docs.InteractiveTutorial.Models.step_id(),
            title: String.t(),
            content: String.t(),
            example_code: String.t() | nil,
            exercise: map() | nil,
            validation: function() | nil,
            hints: [String.t()],
            next_steps: [Raxol.Docs.InteractiveTutorial.Models.step_id()],
            interactive_elements: [map()]
          }
  end

  defmodule Tutorial do
    @moduledoc """
    Represents a complete tutorial with multiple steps.
    """
    defstruct [
      :id,
      :title,
      :description,
      :tags,
      :difficulty,
      :estimated_time,
      :prerequisites,
      :steps,
      :metadata
    ]

    @type t :: %__MODULE__{
            id: Raxol.Docs.InteractiveTutorial.Models.tutorial_id(),
            title: String.t(),
            description: String.t(),
            tags: [String.t()],
            difficulty: :beginner | :intermediate | :advanced,
            estimated_time: integer(),
            prerequisites: [String.t()],
            steps: [Step.t()],
            metadata: map()
          }
  end
end
