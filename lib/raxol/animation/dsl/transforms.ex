defmodule Raxol.Animation.DSL.Transforms do
  @moduledoc """
  Transform calculation functions for the Animation DSL.

  Computes CSS-style transform strings for slide animations.
  """

  @doc "Calculates from/to transforms for a generic slide (relative movement)."
  def calculate_slide_transform(direction, distance) do
    case direction do
      :up -> {"translateY(#{distance}px)", "translateY(0px)"}
      :down -> {"translateY(-#{distance}px)", "translateY(0px)"}
      :left -> {"translateX(#{distance}px)", "translateX(0px)"}
      :right -> {"translateX(-#{distance}px)", "translateX(0px)"}
    end
  end

  @doc "Calculates from/to transforms for a slide-in animation."
  def calculate_slide_in_transform(direction, distance) do
    case direction do
      :up -> {"translateY(#{distance}px)", "translateY(0px)"}
      :down -> {"translateY(-#{distance}px)", "translateY(0px)"}
      :left -> {"translateX(-#{distance}px)", "translateX(0px)"}
      :right -> {"translateX(#{distance}px)", "translateX(0px)"}
    end
  end

  @doc "Calculates from/to transforms for a slide-out animation."
  def calculate_slide_out_transform(direction, distance) do
    case direction do
      :up -> {"translateY(0px)", "translateY(-#{distance}px)"}
      :down -> {"translateY(0px)", "translateY(#{distance}px)"}
      :left -> {"translateY(0px)", "translateX(-#{distance}px)"}
      :right -> {"translateY(0px)", "translateX(#{distance}px)"}
    end
  end
end
