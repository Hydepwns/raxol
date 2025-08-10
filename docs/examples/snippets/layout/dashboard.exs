defmodule Dashboard do
  # use Raxol.App, otp_app: :raxol
  use Raxol.Component

  alias Raxol.View
  alias Raxol.View.Elements

  # @impl Raxol.App
  # def init(_flags) do
  #   state = %{}
  #   {:ok, state}
  # end
  @impl Raxol.Component
  def mount(_params, _session, socket) do
    # No initial state needed for this static layout
    {:ok, socket}
  end

  # @impl Raxol.App
  # def update(msg, state) do
  #   # Handle updates later
  #   {:ok, state}
  # end

  @impl Raxol.Component
  # def render(state) do
  def render(assigns) do
    # use Raxol.View
    ~V"""
    <.box width="100%" height="100%" border=:rounded padding=1>
      <.column width="100%" height="100%" gap=1>
        # Header Row
        <.row width="100%" height=3>
          <.panel
            title="Dashboard Header"
            width="100%"
            border=:line
            padding=1
            align=:center
            justify=:center
          >
            <.text bold fg=:yellow>Complex Layout Example</.text>
          </.panel>
        </.row>

        # Main Content Row (Sidebar + Primary)
        <.row flex=1 width="100%" gap=1>
          # Sidebar - Align items bottom-right
          <.column
            width=25
            border={{:line, fg: :cyan}}
            padding=1
            gap=1
            align=:end
            justify=:end
          >
            <.text bold fg=:cyan>Sidebar</.text>
            <.text>Item 1</.text>
            <.text>Item 2</.text>
            # Spacer pushes content down
            <.box flex=1 />
            <.text fg=:white>Status: Ready</.text>
          </.column>

          # Primary Content Area
          <.column flex=1 gap=1>
            # Top Row of Panels - Using flex for height distribution
            # Takes 2/3 of vertical space
            <.row flex=2 gap=1>
              <.panel
                title="Panel A"
                flex=1
                border={{:double, fg: :magenta}}
                padding=1
                align=:start
                justify=:start
              >
                <.text fg=:white>Content A...</.text>
                <.text fg=:magenta underline>Details...</.text>
              </.panel>

              <.panel
                title="Panel B"
                flex=1
                border={{:heavy, fg: :yellow}}
                padding=1
                align=:center
                justify=:center
              >
                <.text fg=:white bold>Centered Content B</.text>
              </.panel>
            </.row>

            # Bottom Panel - Using flex for height
            <.panel
              title="Panel C (Logs?)"
              flex=1
              border={{:dashed, fg: :green}}
              padding=1
              align=:start
              justify=:start
            >
              <.text fg=:white>Log entry 1...</.text>
              <.text fg=:green>Log entry 2...</.text>
              <.text fg=:gray>Log entry 3...</.text>
            </.panel>
          </.column>
        </.row>

        # Footer Row - Justify content centrally
        <.row width="100%" height=1 bg=:gray align=:center justify=:center>
          <.text fg=:black bold>Footer | Status: OK</.text>
        </.row>
      </.column>
    </.box>
    """
  end
end
