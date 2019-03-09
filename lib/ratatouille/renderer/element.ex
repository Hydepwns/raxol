defmodule Ratatouille.Renderer.Element do
  @moduledoc false

  alias __MODULE__, as: Element

  alias Ratatouille.Renderer.Element.{
    Bar,
    Chart,
    Column,
    Label,
    Overlay,
    Panel,
    Row,
    Sparkline,
    Table,
    Tree,
    View
  }

  @type t :: %Element{tag: atom()}

  @enforce_keys [:tag]
  defstruct tag: nil, attributes: %{}, children: []

  ### Element Specs

  @specs [
    bar: [
      description:
        "Block-level element for creating title, status or menu bars",
      renderer: Bar,
      child_tags: [:label],
      attributes: []
    ],
    chart: [
      description: "Element for plotting a series as a multi-line chart",
      renderer: Chart,
      child_tags: [],
      attributes: [
        series:
          {:required, "List of float or integer values representing the series"},
        type:
          {:required,
           "Type of chart to plot. Currently only `:line` is supported"},
        height: {:optional, "Height of the chart in rows"}
      ]
    ],
    column: [
      description: "Container occupying a vertical segment of the grid",
      renderer: Column,
      child_tags: [:panel, :table, :row, :label, :chart, :sparkline, :tree],
      attributes: [
        size:
          {:required,
           "Number of units on the grid that the column should occupy"}
      ]
    ],
    label: [
      description: "Block-level element for displaying text",
      renderer: Label,
      child_tags: [:text],
      attributes: [
        content:
          {:optional, "Binary containing the text content to be displayed"},
        color: {:optional, "Constant representing color to use for foreground"},
        background:
          {:optional, "Constant representing color to use for background"},
        attributes:
          {:optional, "Constant representing style attributes to apply"}
      ]
    ],
    overlay: [
      description: "Container overlaid on top of the view",
      renderer: Overlay,
      child_tags: [:panel, :row],
      attributes: [
        padding: {:optional, "Integer number of units of padding"}
      ]
    ],
    panel: [
      description:
        "Container with a border and title used to demarcate content",
      renderer: Panel,
      child_tags: [:table, :row, :label, :panel, :chart, :sparkline, :tree],
      attributes: [
        color: {:optional, "Color of title"},
        background: {:optional, "Background of title"},
        height:
          {:optional,
           "Height of the table in rows or `:fill` to fill the parent container's box"},
        title: {:optional, "Binary containing the title for the panel"}
      ]
    ],
    row: [
      description:
        "Container used to define grid layouts with one or more columns",
      renderer: Row,
      child_tags: [:column],
      attributes: []
    ],
    sparkline: [
      description: "Element for plotting a series in a single line",
      renderer: Sparkline,
      child_tags: [],
      attributes: [
        series:
          {:required, "List of float or integer values representing the series"}
      ]
    ],
    table: [
      description: "Container for displaying data in rows and columns",
      renderer: Table,
      child_tags: [:table_row],
      attributes: []
    ],
    table_cell: [
      description: "Element representing a table cell",
      child_tags: [],
      attributes: [
        content:
          {:required, "Binary containing the text content to be displayed"},
        color: {:optional, "Constant representing color to use for foreground"},
        background:
          {:optional, "Constant representing color to use for background"},
        attributes:
          {:optional, "Constant representing style attributes to apply"}
      ]
    ],
    table_row: [
      description: "Container representing a row of the table",
      child_tags: [:table_cell],
      attributes: [
        color: {:optional, "Constant representing color to use for foreground"},
        background:
          {:optional, "Constant representing color to use for background"},
        attributes:
          {:optional, "Constant representing style attributes to apply"}
      ]
    ],
    text: [
      description: "Inline element for displaying uniformly-styled text",
      child_tags: [],
      attributes: [
        content:
          {:required, "Binary containing the text content to be displayed"},
        color: {:optional, "Constant representing color to use for foreground"},
        background:
          {:optional, "Constant representing color to use for background"},
        attributes:
          {:optional, "Constant representing style attributes to apply"}
      ]
    ],
    tree: [
      description: "Container for displaying data as a tree of nodes",
      renderer: Tree,
      child_tags: [:tree_node],
      attributes: []
    ],
    tree_node: [
      description: "Container representing a tree node",
      child_tags: [:tree_node],
      attributes: [
        content: {:required, "Binary label for the node"}
      ]
    ],
    view: [
      description: "Top-level container",
      renderer: View,
      child_tags: [:label, :row, :panel, :overlay],
      attributes: [
        top_bar: {:optional, "A `:bar` element to occupy the view's first row"},
        bottom_bar:
          {:optional, "A `:bar` element to occupy the view's last row"}
      ]
    ]
  ]

  def specs, do: @specs
end
