defmodule Raxol.UI.Layout.TableTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Layout.Table

  describe "Column Width Calculation" do
    test "respects fixed column widths" do
      # Define a table element as it would come from Elements.table
      table_element = %{
        type: :table,
        attrs: %{
          id: :test_table,
          columns: [
            %{header: "Col A", key: :a, width: 10},
            %{header: "Col B", key: :b, width: 20}
            # Add other necessary attrs if needed by measure_and_position
          ],
          data: [%{a: "Data1", b: "Data2"}],
          style: %{} # Basic style
        }
      }

      # Define available space
      space = %{x: 0, y: 0, width: 80, height: 24}

      # Call the function under test
      result = Table.measure_and_position(table_element, space, [])

      # Assertions
      assert [%{attrs: %{_col_widths: calculated_widths}}] = result

      # Check if the calculated widths match the fixed widths defined in columns
      assert calculated_widths == [10, 20]

      # Assert on the final width/height of the positioned element
      # Total width = col_widths_sum + separator_width = (10 + 20) + 3 = 33
      # Total height = header(1) + separator(1) + data_rows(1) = 3
      # Assuming space (80x24) is large enough, final dimensions should match calculated ones.
      assert [%{width: final_width, height: final_height}] = result
      assert final_width == 33
      assert final_height == 3
    end

    test "clamps width when content exceeds available space" do
      table_element = %{
        type: :table,
        attrs: %{
          id: :clamp_table,
          columns: [
            %{header: "Col A", key: :a, width: 20},
            %{header: "Col B", key: :b, width: 25},
            %{header: "Col C", key: :c, width: 30} # Total width = 20+25+30 + 3+3 = 81
          ],
          data: [%{a: 1, b: 2, c: 3}],
          style: %{}
        }
      }

      # Provide limited space
      space = %{x: 0, y: 0, width: 50, height: 10}

      result = Table.measure_and_position(table_element, space, [])

      # Assert on the final dimensions
      assert [%{width: final_width, height: final_height, attrs: %{_col_widths: calculated_widths}}] = result

      # Column widths themselves should still be the original ones
      assert calculated_widths == [20, 25, 30]
      # Final width should be clamped to space.width
      assert final_width == 50
      # Final height should be calculated (header+sep+data = 1+1+1=3) and not clamped
      assert final_height == 3
    end

    # TODO: Add tests for fallback width calculation (when :columns is missing).
    # TODO: Clarify/test handling of :auto column widths.
    # TODO: Add test for height clamping.
  end
end
