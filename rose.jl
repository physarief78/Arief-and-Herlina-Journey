using JSON
using Printf

# -------------------------
# (Your original math/data)
# -------------------------
ppr = 3.6
nr  = 30
pr  = 30
pn  = 40
pf  = 2
ps  = 5/4
ol  = [0.2, 1.02]

pt = (1/ppr)*pi*2
θ = range(0, stop=pn*pt, length=pn*pr+1)
r_vals = range(0, stop=1, length=nr)

R    = [r for r in r_vals, _ in θ]
THETA = [t for _ in r_vals, t in θ]

x = 1 .- (((ps .* ((1 .- mod.(ppr .* THETA, 2pi) ./ pi).^2) .- 1/4).^2) ./ 2)

phi_vec = (pi/2) .* (range(ol[1], stop=ol[2], length=pn*pr+1)).^2
sin_phi = sin.(phi_vec')
cos_phi = cos.(phi_vec')

y  = pf .* (R.^2) .* ((1.28 .* R .- 1).^2) .* sin_phi
R2 = (x .* (R .* sin_phi)) .+ (y .* cos_phi)

X = R2 .* sin.(THETA)
Y = R2 .* cos.(THETA)
Z = x .* ((R .* cos_phi) .- (y .* sin_phi))
C = sqrt.(X.^2 .+ Y.^2 .+ Z.^2)

# -------------------------
# trace dicts (Plotly.js)
# -------------------------
# IMPORTANT: keep the flower color exactly as before (violet -> blue)
trace1 = Dict(
    "type" => "surface",
    "x" => X,
    "y" => Y,
    "z" => Z,
    "surfacecolor" => C,
    "colorscale" => [[0.0, "Red"], [1.0, "Blue"]],  # unchanged
    "showscale" => false,
    "name" => "violet-blue",
    "scene" => "scene"   # explicitly assign to first 3D scene
)

# Keep the second plot and its hot reversed color exactly as before
trace2 = Dict(
    "type" => "surface",
    "x" => X,
    "y" => Y,
    "z" => Z,
    "surfacecolor" => C,
    "colorscale" => "Hot",        # unchanged
    "reversescale" => true,       # unchanged
    "showscale" => false,
    "name" => "hot",
    "scene" => "scene2"           # explicitly assign to second 3D scene
)

data = [trace1, trace2]

# ---------- shared visual properties ----------
# Note: we intentionally REMOVE the Plotly layout title (we'll use the HTML header instead)
paper_bg = "black"
plot_bg  = "black"
font_common = Dict("size" => 12, "color" => "white")

axis_title_size = 16
tick_size = 12
# title_size variable left available if you want to use it elsewhere
title_size = 40

function make_scene(domain_x, domain_y)
    Dict(
        "domain" => Dict("x" => domain_x, "y" => domain_y),
        "bgcolor" => "black",
        "xaxis" => Dict(
            "title" => Dict("text" => "X", "font" => Dict("size" => axis_title_size, "color" => "white")),
            "tickfont" => Dict("size" => tick_size, "color" => "white"),
            "showbackground" => true,
            "backgroundcolor" => "black",
            "gridcolor" => "gray"
        ),
        "yaxis" => Dict(
            "title" => Dict("text" => "Y", "font" => Dict("size" => axis_title_size, "color" => "white")),
            "tickfont" => Dict("size" => tick_size, "color" => "white"),
            "showbackground" => true,
            "backgroundcolor" => "black",
            "gridcolor" => "gray"
        ),
        "zaxis" => Dict(
            "title" => Dict("text" => "Z", "font" => Dict("size" => axis_title_size, "color" => "white")),
            "tickfont" => Dict("size" => tick_size, "color" => "white"),
            "showbackground" => true,
            "backgroundcolor" => "black",
            "gridcolor" => "gray"
        )
    )
end

layout_common = Dict(
    "paper_bgcolor" => paper_bg,
    "plot_bgcolor"  => plot_bg,
    "font" => font_common
    # intentionally NO "title" key here — we use the HTML header above the plot
)

# Horizontal layout (side-by-side)
scene1_H = make_scene([0.0, 0.5], [0.0, 1.0])
scene2_H = make_scene([0.5, 1.0], [0.0, 1.0])

layoutH = deepcopy(layout_common)
layoutH["scene"]  = scene1_H
layoutH["scene2"] = scene2_H
# Add a small top margin to avoid the plot touching the header
layoutH["margin"] = Dict("t" => 12, "l" => 60, "r" => 60, "b" => 60)

# Vertical layout (stacked)
scene1_V = make_scene([0.0, 1.0], [0.5, 1.0])
scene2_V = make_scene([0.0, 1.0], [0.0, 0.5])

layoutV = deepcopy(layout_common)
layoutV["scene"]  = scene1_V
layoutV["scene2"] = scene2_V
layoutV["margin"] = Dict("t" => 12, "l" => 60, "r" => 60, "b" => 60)

# -------------------------
# Write responsive HTML using Plotly.js CDN
# -------------------------
# We move the title into an HTML header above the plot, and use flexbox for layout
html = """
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Dear Herlina Mawarni My Precious Friend</title>
  <style>
    html, body { height:100%; margin:0; background: black; }
    /* Container holds header + plot; header doesn't overlap the plot */
    #container { display: flex; flex-direction: column; height: 100vh; }
    #plot-title {
      text-align: center;
      color: white;
      padding: 12px 10px;
      box-sizing: border-box;
    }
    #plot-title h1 { margin: 0; font-weight: 600; font-size: 40px; line-height: 1.05; }
    #plot { flex: 1 1 auto; width: 100%; min-height: 0; } /* flex so it fills remaining space */

    /* Mobile adjustments */
    @media (max-width: 700px) {
      #plot-title h1 { font-size: 26px; }
      #plot-title { padding: 10px 8px; }
    }

    /* Optional: keep plot background black and remove page scrollbars on mobile */
    .js-plotly-plot { background: black !important; }
    body, html { -webkit-font-smoothing:antialiased; -moz-osx-font-smoothing:grayscale; }
  </style>
</head>
<body>
  <div id="container">
    <div id="plot-title"><h1>Happy Eid Mubarak, Erlin!</h1></div>
    <div id="plot"></div>
  </div>

  <!-- Plotly.js from official CDN -->
  <script src="https://cdn.plot.ly/plotly-2.24.1.min.js"></script>

  <script>
    const data = $(JSON.json(data));
    const layoutH = $(JSON.json(layoutH));
    const layoutV = $(JSON.json(layoutV));
    const WIDTH_THRESHOLD = 700;

    // base config for Plotly
    const baseConfig = {
      responsive: true,
      displaylogo: false
      // keep modebar visible (you can still remove buttons if you like)
    };

    function renderAdaptive() {
      const w = window.innerWidth;
      const baseLayout = (w < WIDTH_THRESHOLD) ? layoutV : layoutH;
      const chosenLayout = JSON.parse(JSON.stringify(baseLayout));

      // adjust a small top margin depending on screen size (header already takes space)
      if (w < WIDTH_THRESHOLD) {
        chosenLayout.margin = chosenLayout.margin || {};
        chosenLayout.margin.t = Math.max(8, chosenLayout.margin.t || 8);
      } else {
        chosenLayout.margin = chosenLayout.margin || {};
        chosenLayout.margin.t = Math.max(12, chosenLayout.margin.t || 12);
      }

      Plotly.react('plot', data, chosenLayout, baseConfig);
    }

    renderAdaptive();
    let resizeTimer = null;
    window.addEventListener('resize', () => {
      if (resizeTimer) clearTimeout(resizeTimer);
      resizeTimer = setTimeout(() => {
        renderAdaptive();
        resizeTimer = null;
      }, 120);
    });
  </script>
</body>
</html>
"""

html = replace(html, "\$(JSON.json(data))" => JSON.json(data))
html = replace(html, "\$(JSON.json(layoutH))" => JSON.json(layoutH))
html = replace(html, "\$(JSON.json(layoutV))" => JSON.json(layoutV))

outfile = "Eid_Mubarak_Erlin.html"
open(outfile, "w") do io
    write(io, html)
end

@printf "Saved responsive file: %s\n" outfile
