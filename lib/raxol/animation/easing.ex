defmodule Raxol.Animation.Easing do
  @moduledoc """
  Provides easing functions for animations.
  
  Easing functions control how an animation progresses over time.
  They can make animations feel more natural by varying the speed
  at different points in the animation.
  
  All functions take a progress value between 0.0 and 1.0 and return
  an eased value in the same range.
  """
  
  @doc """
  Linear easing (no easing).
  
  ## Examples
  
      iex> Easing.linear(0.5)
      0.5
  """
  def linear(t), do: t
  
  @doc """
  Quadratic ease-in.
  
  ## Examples
  
      iex> Easing.ease_in_quad(0.5)
      0.25
  """
  def ease_in_quad(t), do: t * t
  
  @doc """
  Quadratic ease-out.
  
  ## Examples
  
      iex> Easing.ease_out_quad(0.5)
      0.75
  """
  def ease_out_quad(t), do: t * (2 - t)
  
  @doc """
  Quadratic ease-in-out.
  
  ## Examples
  
      iex> Easing.ease_in_out_quad(0.5)
      0.5
  """
  def ease_in_out_quad(t) do
    if t < 0.5 do
      2 * t * t
    else
      -1 + (4 - 2 * t) * t
    end
  end
  
  @doc """
  Cubic ease-in.
  
  ## Examples
  
      iex> Easing.ease_in_cubic(0.5)
      0.125
  """
  def ease_in_cubic(t), do: t * t * t
  
  @doc """
  Cubic ease-out.
  
  ## Examples
  
      iex> Easing.ease_out_cubic(0.5)
      0.875
  """
  def ease_out_cubic(t) do
    t = t - 1
    t * t * t + 1
  end
  
  @doc """
  Cubic ease-in-out.
  
  ## Examples
  
      iex> Easing.ease_in_out_cubic(0.5)
      0.5
  """
  def ease_in_out_cubic(t) do
    if t < 0.5 do
      4 * t * t * t
    else
      (t - 1) * (2 * t - 2) * (2 * t - 2) + 1
    end
  end
  
  @doc """
  Elastic ease-in.
  
  ## Examples
  
      iex> Easing.ease_in_elastic(0.5)
      0.5
  """
  def ease_in_elastic(t) do
    c4 = 2 * :math.pi() / 3
    if t == 0, do: 0,
    else: if(t == 1, do: 1,
    else: -:math.pow(2, 10 * t - 10) * :math.sin((t * 10 - 10.75) * c4))
  end
  
  @doc """
  Elastic ease-out.
  
  ## Examples
  
      iex> Easing.ease_out_elastic(0.5)
      0.5
  """
  def ease_out_elastic(t) do
    c4 = 2 * :math.pi() / 3
    if t == 0, do: 0,
    else: if(t == 1, do: 1,
    else: :math.pow(2, -10 * t) * :math.sin((t * 10 - 0.75) * c4) + 1)
  end
  
  @doc """
  Elastic ease-in-out.
  
  ## Examples
  
      iex> Easing.ease_in_out_elastic(0.5)
      0.5
  """
  def ease_in_out_elastic(t) do
    c5 = 2 * :math.pi() / 4.5
    if t == 0, do: 0,
    else: if(t == 1, do: 1,
    else: if(t < 0.5) do
      -(:math.pow(2, 20 * t - 10) * :math.sin((20 * t - 11.125) * c5)) / 2
    else
      (:math.pow(2, -20 * t + 10) * :math.sin((20 * t - 11.125) * c5)) / 2 + 1
    end)
  end
  
  @doc """
  Standard ease-in.
  
  ## Examples
  
      iex> Easing.ease_in(0.5)
      0.25
  """
  def ease_in(t), do: ease_in_quad(t)
  
  @doc """
  Standard ease-out.
  
  ## Examples
  
      iex> Easing.ease_out(0.5)
      0.75
  """
  def ease_out(t), do: ease_out_quad(t)
  
  @doc """
  Standard ease-in-out.
  
  ## Examples
  
      iex> Easing.ease_in_out(0.5)
      0.5
  """
  def ease_in_out(t), do: ease_in_out_quad(t)
end 