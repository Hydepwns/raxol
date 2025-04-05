defmodule Raxol.Animation.EasingTest do
  use ExUnit.Case
  
  alias Raxol.Animation.Easing
  
  describe "Easing Functions" do
    test "linear easing" do
      assert Easing.linear(0.0) == 0.0
      assert Easing.linear(0.5) == 0.5
      assert Easing.linear(1.0) == 1.0
    end
    
    test "quadratic ease-in" do
      assert Easing.ease_in_quad(0.0) == 0.0
      assert Easing.ease_in_quad(0.5) == 0.25
      assert Easing.ease_in_quad(1.0) == 1.0
    end
    
    test "quadratic ease-out" do
      assert Easing.ease_out_quad(0.0) == 0.0
      assert Easing.ease_out_quad(0.5) == 0.75
      assert Easing.ease_out_quad(1.0) == 1.0
    end
    
    test "quadratic ease-in-out" do
      assert Easing.ease_in_out_quad(0.0) == 0.0
      assert Easing.ease_in_out_quad(0.5) == 0.5
      assert Easing.ease_in_out_quad(1.0) == 1.0
    end
    
    test "cubic ease-in" do
      assert Easing.ease_in_cubic(0.0) == 0.0
      assert Easing.ease_in_cubic(0.5) == 0.125
      assert Easing.ease_in_cubic(1.0) == 1.0
    end
    
    test "cubic ease-out" do
      assert Easing.ease_out_cubic(0.0) == 0.0
      assert Easing.ease_out_cubic(0.5) == 0.875
      assert Easing.ease_out_cubic(1.0) == 1.0
    end
    
    test "cubic ease-in-out" do
      assert Easing.ease_in_out_cubic(0.0) == 0.0
      assert Easing.ease_in_out_cubic(0.5) == 0.5
      assert Easing.ease_in_out_cubic(1.0) == 1.0
    end
    
    test "elastic ease-in" do
      assert Easing.ease_in_elastic(0.0) == 0.0
      assert Easing.ease_in_elastic(1.0) == 1.0
      # Test middle value (approximate due to floating point)
      assert_in_delta Easing.ease_in_elastic(0.5), 0.5, 0.1
    end
    
    test "elastic ease-out" do
      assert Easing.ease_out_elastic(0.0) == 0.0
      assert Easing.ease_out_elastic(1.0) == 1.0
      # Test middle value (approximate due to floating point)
      assert_in_delta Easing.ease_out_elastic(0.5), 0.5, 0.1
    end
    
    test "elastic ease-in-out" do
      assert Easing.ease_in_out_elastic(0.0) == 0.0
      assert Easing.ease_in_out_elastic(1.0) == 1.0
      # Test middle value (approximate due to floating point)
      assert_in_delta Easing.ease_in_out_elastic(0.5), 0.5, 0.1
    end
    
    test "standard ease-in" do
      assert Easing.ease_in(0.0) == 0.0
      assert Easing.ease_in(0.5) == 0.25
      assert Easing.ease_in(1.0) == 1.0
    end
    
    test "standard ease-out" do
      assert Easing.ease_out(0.0) == 0.0
      assert Easing.ease_out(0.5) == 0.75
      assert Easing.ease_out(1.0) == 1.0
    end
    
    test "standard ease-in-out" do
      assert Easing.ease_in_out(0.0) == 0.0
      assert Easing.ease_in_out(0.5) == 0.5
      assert Easing.ease_in_out(1.0) == 1.0
    end
    
    test "all functions maintain range" do
      functions = [
        &Easing.linear/1,
        &Easing.ease_in_quad/1,
        &Easing.ease_out_quad/1,
        &Easing.ease_in_out_quad/1,
        &Easing.ease_in_cubic/1,
        &Easing.ease_out_cubic/1,
        &Easing.ease_in_out_cubic/1,
        &Easing.ease_in_elastic/1,
        &Easing.ease_out_elastic/1,
        &Easing.ease_in_out_elastic/1,
        &Easing.ease_in/1,
        &Easing.ease_out/1,
        &Easing.ease_in_out/1
      ]
      
      Enum.each(functions, fn fun ->
        assert fun.(0.0) >= 0.0
        assert fun.(0.0) <= 1.0
        assert fun.(0.5) >= 0.0
        assert fun.(0.5) <= 1.0
        assert fun.(1.0) >= 0.0
        assert fun.(1.0) <= 1.0
      end)
    end
  end
end 