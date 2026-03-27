# Generates a social preview image for Raxol's GitHub repo.
#
# Renders a Lorenz attractor via Raxol's BrailleCanvas, outputs an HTML file
# styled with Synthwave '84 neon glow, then screenshot with headless Chrome.
#
# Usage:
#   mix run scripts/social_preview.exs
#   Then screenshot (or the script attempts it automatically):
#     open scripts/social_preview.html

alias Raxol.UI.Charts.BrailleCanvas

# -- Lorenz attractor computation --

sigma = 10.0
rho = 28.0
beta = 8.0 / 3.0
dt = 0.005
steps = 10_000

{points, _} =
  Enum.reduce(1..steps, {[{1.0, 1.0, 1.0}], {1.0, 1.0, 1.0}}, fn _,
                                                                 {acc,
                                                                  {x, y, z}} ->
    dx = sigma * (y - x)
    dy = x * (rho - z) - y
    dz = x * y - beta * z
    nx = x + dx * dt
    ny = y + dy * dt
    nz = z + dz * dt
    {[{nx, ny, nz} | acc], {nx, ny, nz}}
  end)

# -- Canvas setup --

canvas_w = 80
canvas_h = 25
canvas = BrailleCanvas.new(canvas_w, canvas_h)

{dot_w, dot_h} = BrailleCanvas.get_dimensions(canvas)

# Compute bounding boxes for scaling
xs = Enum.map(points, &elem(&1, 0))
ys = Enum.map(points, &elem(&1, 1))
zs = Enum.map(points, &elem(&1, 2))

x_min = Enum.min(xs)
x_max = Enum.max(xs)
y_min = Enum.min(ys)
y_max = Enum.max(ys)
z_min = Enum.min(zs)
z_max = Enum.max(zs)

# Scaling helper: map a value from [lo, hi] to [0, size-1] with padding
scale = fn val, lo, hi, size ->
  padding = 2
  range = hi - lo

  if range == 0.0,
    do: div(size, 2),
    else: round((val - lo) / range * (size - 1 - padding * 2) + padding)
end

# -- Plot two projections onto BrailleCanvas layers --

# Layer 0 (cyan): x vs z projection
canvas =
  Enum.reduce(points, canvas, fn {x, _y, z}, c ->
    dx = scale.(x, x_min, x_max, dot_w)
    dy = scale.(z, z_min, z_max, dot_h)
    BrailleCanvas.put_dot(c, dx, dy, 0)
  end)

# Layer 1 (magenta): y vs z projection, slight offset for visual depth
canvas =
  Enum.reduce(points, canvas, fn {_x, y, z}, c ->
    dx = scale.(y, y_min, y_max, dot_w) + 3
    dy = scale.(z, z_min, z_max, dot_h) + 2
    BrailleCanvas.put_dot(c, dx, dy, 1)
  end)

# -- Render to cells --

color_map = %{0 => :cyan, 1 => :magenta}
cells = BrailleCanvas.to_cells_multicolor(canvas, {0, 0}, color_map)

# -- Build HTML --

color_hex = %{
  cyan: "#03edf9",
  magenta: "#ff7edb",
  default: "#534267"
}

# Group cells by row
rows =
  cells
  |> Enum.group_by(fn {_x, y, _char, _fg, _bg, _attrs} -> y end)
  |> Enum.sort_by(&elem(&1, 0))

html_rows =
  Enum.map(rows, fn {_y, row_cells} ->
    sorted =
      Enum.sort_by(row_cells, fn {x, _y, _char, _fg, _bg, _attrs} -> x end)

    spans =
      Enum.map(sorted, fn {_x, _y, char, fg, _bg, _attrs} ->
        hex = Map.get(color_hex, fg, "#534267")
        # Only glow non-empty braille (not the blank braille U+2800)
        glow =
          if char != <<0x2800::utf8>> do
            "text-shadow:0 0 6px #{hex},0 0 14px #{hex},0 0 28px #{hex};"
          else
            ""
          end

        ~s(<span style="color:#{hex};#{glow}">#{char}</span>)
      end)

    Enum.join(spans)
  end)

chart_html = Enum.join(html_rows, "\n")

html = """
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body {
    width: 1280px;
    height: 640px;
    overflow: hidden;
    background: #2b213a;
  }
  .container {
    display: flex;
    width: 1280px;
    height: 640px;
    align-items: center;
    overflow: hidden;
  }
  .chart {
    width: 780px;
    flex-shrink: 0;
    padding: 30px 20px 30px 40px;
    font-family: 'Monaspace Neon', 'JetBrains Mono', 'Fira Code', monospace;
    font-size: 16.5px;
    line-height: 1.15;
    white-space: pre;
    letter-spacing: 0.5px;
  }
  .wordmark {
    flex: 1;
    padding: 0 60px 0 0;
    text-align: center;
  }
  .title {
    font-family: 'Monaspace Neon', 'JetBrains Mono', 'Fira Code', monospace;
    font-size: 76px;
    font-weight: 700;
    letter-spacing: 10px;
    color: #f0eff1;
    text-shadow:
      0 0 10px #ff7edb,
      0 0 30px #ff7edb,
      0 0 60px #ff7edb,
      0 0 100px #ff7edb44;
    margin-bottom: 32px;
  }
  .tagline {
    font-family: 'Monaspace Neon', 'JetBrains Mono', 'Fira Code', monospace;
    font-size: 23px;
    font-weight: 400;
    line-height: 1.7;
    color: #72f1b8;
    text-shadow:
      0 0 8px #72f1b866,
      0 0 20px #72f1b844;
    letter-spacing: 1px;
  }
  .tagline .accent {
    color: #fede5d;
    text-shadow:
      0 0 8px #fede5d66,
      0 0 20px #fede5d44;
  }
</style>
</head>
<body>
<div class="container">
  <div class="chart">
#{chart_html}
  </div>
  <div class="wordmark">
    <div class="title">RAXOL</div>
    <div class="tagline">
      <span class="accent">OTP</span>-native<br>
      terminal<br>
      framework<br>
      for <span class="accent">Elixir</span>
    </div>
  </div>
</div>
</body>
</html>
"""

output_path = Path.join([__DIR__, "social_preview.html"])
File.write!(output_path, html)
IO.puts("Wrote #{output_path}")

# Attempt headless Chrome screenshot
project_root = Path.dirname(__DIR__)
images_dir = Path.join([project_root, "assets", "images"])
File.mkdir_p!(images_dir)
png_path = Path.join(images_dir, "social-preview.png")

chrome_paths = [
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Chromium.app/Contents/MacOS/Chromium"
]

chrome =
  Enum.find(chrome_paths, fn p -> File.exists?(p) end)

if chrome do
  # Chrome headless needs a file:// URL
  file_url = "file://#{output_path}"

  args = [
    "--headless",
    "--screenshot=#{png_path}",
    "--window-size=1280,640",
    "--default-background-color=ff2b213a",
    "--force-device-scale-factor=1",
    "--hide-scrollbars",
    file_url
  ]

  IO.puts("Taking screenshot with Chrome...")

  case System.cmd(chrome, args, stderr_to_stdout: true) do
    {_output, 0} ->
      IO.puts("Wrote #{png_path}")

    {output, code} ->
      IO.puts("Chrome exited with #{code}: #{output}")
      IO.puts("Open #{output_path} in a browser to screenshot manually.")
  end
else
  IO.puts(
    "Chrome not found. Open #{output_path} in a browser to screenshot manually."
  )
end
