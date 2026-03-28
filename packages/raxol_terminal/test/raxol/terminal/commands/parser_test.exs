defmodule Raxol.Terminal.Commands.ParserTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Commands.CommandsParser, as: Parser

  describe "parse_params/1" do
    test ~c"parses empty string as empty list" do
      assert Parser.parse_params("") == []
    end

    test ~c"parses nil as empty list" do
      assert Parser.parse_params(nil) == []
    end

    test ~c"parses simple parameters" do
      assert Parser.parse_params("5;10;15") == [5, 10, 15]
    end

    test ~c"handles empty parameters as nil" do
      assert Parser.parse_params("5;;15") == [5, nil, 15]
      assert Parser.parse_params(";5;") == [nil, 5, nil]
      assert Parser.parse_params(";;") == [nil, nil, nil]
    end

    test ~c"handles sub-parameters with colon notation" do
      assert Parser.parse_params("5:1;10:2;15:3") == [[5, 1], [10, 2], [15, 3]]
    end

    test ~c"handles mixed parameter types" do
      assert Parser.parse_params("5;10:2;;7:1:3") == [
               5,
               [10, 2],
               nil,
               [7, 1, 3]
             ]
    end

    test ~c"handles invalid numeric parameters" do
      assert Parser.parse_params("5;abc;15") == [5, nil, 15]
    end
  end

  describe "get_param/3" do
    test ~c"gets parameter at index" do
      assert Parser.get_param([5, 10, 15], 0) == 5
    end

    test ~c"returns default for missing parameters" do
      assert Parser.get_param([5, 10], 3) == 1
      assert Parser.get_param([], 1) == 1
    end

    test ~c"uses specified default value" do
      assert Parser.get_param([5, 10], 3, 0) == 0
    end

    test ~c"handles nil parameters in list" do
      assert Parser.get_param([5, nil, 15], 1) == 1
      assert Parser.get_param([5, nil, 15], 1, 0) == 0
    end

    test ~c"get_param/3 handles nil parameters in list" do
      # Check index 1 (second element) which is nil, expect default 1
      assert Parser.get_param([5, nil, 15], 1) == 1
    end
  end

  describe "parse_int/1" do
    test ~c"parses valid integers" do
      assert Parser.parse_int("123") == 123
      assert Parser.parse_int("0") == 0
      assert Parser.parse_int("-42") == -42
    end

    test ~c"returns nil for invalid integers" do
      assert Parser.parse_int("abc") == nil
      assert Parser.parse_int("12.34") == nil
      assert Parser.parse_int("") == nil
    end

    test ~c"parse_int/1 parses valid integers" do
      assert Parser.get_param([5, 10, 15], 0) == 5
      # Check index 1 (second element)
      assert Parser.get_param([5, 10, 15], 1) == 10
    end

    test ~c"get_param/3 uses specified default value" do
      assert Parser.get_param([5, 10], 3, 0) == 0
    end
  end
end
