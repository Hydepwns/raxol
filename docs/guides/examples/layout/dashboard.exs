defmodule Dashboard do
  use Raxol.App, otp_app: :raxol

  alias Raxol.View

  @impl Raxol.App
  def init(_flags) do
    state = %{}
    {:ok, state}
  end

  @impl Raxol.App
  def update(msg, state) do
    # Handle updates later
    {:ok, state}
  end

  @impl Raxol.App
  def render(state) do
    use Raxol.View

    box width: "100%", height: "100%", border: :rounded, padding: 1 do
      column width: "100%", height: "100%", gap: 1 do
        # Header Row
        row width: "100%", height: 3 do
          panel title: "Dashboard Header",
                width: "100%",
                border: :line,
                padding: 1,
                align: :center,
                justify: :center do
            text("Complex Layout Example", bold: true, fg: :yellow)
          end
        end

        # Main Content Row (Sidebar + Primary)
        row flex: 1, width: "100%", gap: 1 do
          # Sidebar - Align items bottom-right
          column width: 25,
                 border: {:line, fg: :cyan},
                 padding: 1,
                 gap: 1,
                 align: :end,
                 justify: :end do
            text("Sidebar", bold: true, fg: :cyan)
            text("Item 1")
            text("Item 2")
            # Spacer pushes content down
            box flex: 1 do
            end

            text("Status: Ready", fg: :white)
          end

          # Primary Content Area
          column flex: 1, gap: 1 do
            # Top Row of Panels - Using flex for height distribution
            # Takes 2/3 of vertical space
            row flex: 2, gap: 1 do
              panel title: "Panel A",
                    flex: 1,
                    border: {:double, fg: :magenta},
                    padding: 1,
                    align: :start,
                    justify: :start do
                text("Content A...", fg: :white)
                text("Details...", fg: :magenta, underline: true)
              end

              panel title: "Panel B",
                    flex: 1,
                    border: {:heavy, fg: :yellow},
                    padding: 1,
                    align: :center,
                    justify: :center do
                text("Centered Content B", fg: :white, bold: true)
              end
            end

            # Bottom Panel - Using flex for height
            panel title: "Panel C (Logs?)",
                  flex: 1,
                  border: {:dashed, fg: :green},
                  padding: 1,
                  align: :start,
                  justify: :start do
              text("Log entry 1...", fg: :white)
              text("Log entry 2...", fg: :green)
              text("Log entry 3...", fg: :gray)
            end
          end
        end

        # Footer Row - Justify content centrally
        row width: "100%",
            height: 1,
            bg: :gray,
            align: :center,
            justify: :center do
          text("Footer | Status: OK", fg: :black, bold: true)
        end
      end
    end
  end
end
