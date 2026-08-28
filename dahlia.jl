using Plots
using Colors

# Set the backend to PlotlyJS (JavaScript based)
plotlyjs()

# Define parameters
ppr = 12.6        # petals per revolution
nr  = 30          # radius resolution
pr  = 10          # petal resolution
pn  = 140         # total number of petals
pf  = -1.2        # How much the ends of the petals tilt up or down
ol  = [0.11, 1.1]  # How open is it? [inner outer]

pt = (1/ppr) * π * 2
θ = range(0, stop=pn*pt, length=pn*pr+1)
r_vals = range(0, stop=1, length=nr)

# Create meshgrid arrays with "ij" indexing.
R    = [r for r in r_vals, _ in θ]        # size: (nr, length(θ))
THETA = [t for _ in r_vals, t in θ]         # same size

# Compute x (using elementwise broadcasting)
x = 1 .- ( (1 .- (mod.(ppr .* THETA, 2π) ./ π)).^2 .* 0.7 )

# Create phi as a 1D array then broadcast it along rows.
phi_vec = (π/2) .* ((range(ol[1], stop=ol[2], length=pn*pr+1)).^2)
# To broadcast along rows (R has size (nr, pn*pr+1)), we use phi_vec' (a row vector)
φ = phi_vec'  # alias for clarity

# Compute y and an intermediate R2.
y  = pf .* (R.^2) .* ((1.28 .* R .- 1).^2) .* sin.(φ)
R2 = (x .* (R .* sin.(φ))) .+ (y .* cos.(φ))

# Compute Cartesian coordinates.
X = R2 .* sin.(THETA)
Y = R2 .* cos.(THETA)
Z = x .* ((R .* cos.(φ)) .- (y .* sin.(φ)))
# Compute C as the Euclidean norm.
C = sqrt.(X.^2 .+ Y.^2 .+ Z.^2)

# -------------------------------
# Create a custom Listed colormap.
# In Python, the colormap is defined by 256 colors with channels:
#   vals[:,0] from 0.6 to 1, vals[:,1] from 0.1 to 0.8, vals[:,2] from 0.7 to 1.
vals = zeros(256, 3)
vals[:,1] = collect(range(0.6, stop=1, length=256))
vals[:,2] = collect(range(0.1, stop=0.8, length=256))
vals[:,3] = collect(range(0.7, stop=1, length=256))
# Note: Julia arrays index starting at 1. Here, we fill columns 1,2,3.
# Create an array of RGB colors from these channels.
custom_colors = [RGB(vals[i,1], vals[i,2], vals[i,3]) for i in 1:256]
colormap_custom = cgrad(custom_colors)

# -------------------------------
# Create the 3D surface plot.
p = Plots.surface(X, Y, Z,
    color = C,
    colormap = colormap_custom,
    legend = false,
    # Turn off axes:
    axis = false,
    paper_bgcolor = "black",
    plot_bgcolor = "black"
)

display(p)