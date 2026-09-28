using GLMakie
using Makie
using ColorSchemes
using Colors
using Printf
using Dates
using LinearAlgebra
using Random
using Distributions

# ------------------ CUDA detection (robust) ------------------
CUDA_AVAILABLE = try
    import CUDA
    CUDA.has_cuda()
catch e
    @warn "CUDA.jl not available or failed to load. Falling back to CPU. Error: $e"
    false
end

if CUDA_AVAILABLE
    @info "CUDA available — using GPU acceleration for compute."
    import CUDA        # make CUDA symbols visible (CuArray, CUDA.rand, etc.)
end

# ---------------- user settings ----------------
outfile_mp4 = "flower_animation_glmakie_with_stars.mp4"
fps = 24
duration_sec = 30
frames = fps * duration_sec
size_px = (1920, 1080) # 1080p

# grid resolution
nr = 60
pr = 60
pn = 80

# interpolation ranges (Float32)
ppr_range = (Float32(1.0), Float32(5.4))
pf_range  = (Float32(0.5), Float32(3.4))
ps_range  = (Float32(0.5), Float32(2.0))
ol_start_range = (Float32(0.05), Float32(0.25))
ol_end_range   = (Float32(0.6), Float32(1.4))

# color schemes
c_left_cs = ColorScheme([
    RGB{Float32}(0.02f0, 0.03f0, 0.15f0),
    RGB{Float32}(0.0f0,  0.25f0, 0.9f0),
    RGB{Float32}(0.35f0, 0.7f0,  1.0f0),
    RGB{Float32}(0.9f0,  0.95f0, 1.0f0)
])
c_right_cs = reverse(ColorSchemes.hot)

# helpers
lerp(a,b,t) = a + (b-a)*t
ease(t::Float32) = Float32(0.5) * (Float32(1.0) - cos(Float32(pi) * t))

use_cuda = CUDA_AVAILABLE

# ---------- NEW: global flower scale & camera elevation (45°) ----------
# Make the flower smaller by this factor (0.4..0.8 is typical). Adjust to taste.
const flower_scale = 0.55f0

# Camera base: elevation = 45° (pi/4), base azimuth = 45° so we look from upper-right.
const cam_elevation = Float32(pi/4)   # 45 degrees up
const cam_base_az  = Float32(pi/4)    # 45 degrees azimuth (upper-right)

# ---------------- GPU-friendly compute_geometry ----------------
function compute_geometry_gpu(ppr::Float32, pf::Float32, ps::Float32, ol_range::Tuple{Float32,Float32})
    pt = (1f0 / ppr) * (2f0 * Float32(pi))
    θ_cpu = range(0f0, stop = Float32(pn) * pt, length = pn * pr + 1)
    r_vals_cpu = range(0f0, stop = 1f0, length = nr)

    if use_cuda
        θ = CUDA.CuArray(Float32.(θ_cpu))
        r_vals = CUDA.CuArray(Float32.(r_vals_cpu))
        R = CUDA.repeat(r_vals, 1, length(θ))                      # nr x nθ
        THETA = CUDA.repeat(reshape(θ, 1, :), nr, 1)               # nr x nθ
    else
        θ = Float32.(θ_cpu)
        r_vals = Float32.(r_vals_cpu)
        R = [Float32(r) for r in r_vals, _ in θ]
        THETA = [Float32(t) for _ in r_vals, t in θ]
    end

    x = 1f0 .- (((ps .* ((1f0 .- mod.(ppr .* THETA, 2f0*pi) ./ Float32(pi)).^2) .- 1f0/4f0).^2) ./ 2f0)

    phi_vec_cpu = (Float32(pi)/2f0) .* (range(ol_range[1], stop = ol_range[2], length = pn * pr + 1) .^ 2)
    if use_cuda
        phi_vec = CUDA.CuArray(Float32.(phi_vec_cpu))
        sin_phi = sin.(phi_vec')
        cos_phi = cos.(phi_vec')
    else
        sin_phi = sin.(phi_vec_cpu')
        cos_phi = cos.(phi_vec_cpu')
    end

    y = pf .* (R.^2) .* ((1.28f0 .* R .- 1f0).^2) .* sin_phi
    R2 = (x .* (R .* sin_phi)) .+ (y .* cos_phi)
    X = R2 .* sin.(THETA)
    Y = R2 .* cos.(THETA)
    Z = x .* ((R .* cos_phi) .- (y .* sin_phi))
    C = sqrt.(X.^2 .+ Y.^2 .+ Z.^2)

    return (X, Y, Z, C)
end

# style helper
function style_axis!(ax)
    ax.scene.backgroundcolor[] = RGB{Float32}(0f0,0f0,0f0)
    ax.xgridvisible = false
    ax.ygridvisible = false
    ax.zgridvisible = false
    ax.xticksvisible = false
    ax.yticksvisible = false
    ax.zticksvisible = false
    ax.xlabelcolor[] = RGBA{Float32}(1f0,1f0,1f0,1f0)
    ax.ylabelcolor[] = RGBA{Float32}(1f0,1f0,1f0,1f0)
    ax.zlabelcolor[] = RGBA{Float32}(1f0,1f0,1f0,1f0)
    return nothing
end

# ---------- initialize geometry + stars ----------
t0 = 0f0
se0 = ease(t0)
ppr0 = lerp(ppr_range[1], ppr_range[2], se0)
pf0  = lerp(pf_range[1],  pf_range[2],  se0)
ps0  = lerp(ps_range[1],  ps_range[2],  se0)
ol_start0 = lerp(ol_start_range[1], ol_start_range[2], se0)
ol_end0   = lerp(ol_end_range[1], ol_end_range[2], se0)
ol0 = (ol_start0, ol_end0)

Xg0, Yg0, Zg0, Cg0 = compute_geometry_gpu(ppr0, pf0, ps0, ol0)
X0 = use_cuda ? Array(Xg0) : Xg0
Y0 = use_cuda ? Array(Yg0) : Yg0
Z0 = use_cuda ? Array(Zg0) : Zg0
C0 = use_cuda ? Array(Cg0) : Cg0

# ---------- NEW: scale the initial geometry so the flower is smaller ----------
X0 .*= flower_scale
Y0 .*= flower_scale
Z0 .*= flower_scale
C0 .*= flower_scale

rng = MersenneTwister(12345)
nstars = 320
star_x_cpu = Float32.(rand(rng, Uniform(-2.2, 2.2), nstars))
star_y_cpu = Float32.(rand(rng, Uniform(-2.2, 2.2), nstars))
star_z_cpu = Float32.(rand(rng, Uniform(0.8, 3.0), nstars))
star_speed_cpu = Float32.(rand(rng, Uniform(0.008, 0.032), nstars))
star_phase_cpu = Float32.(rand(rng, Uniform(0.0, 2pi), nstars))
star_size_cpu  = Float32.(rand(rng, Uniform(2.0, 6.0), nstars))

if use_cuda
    star_x_gpu = CUDA.CuArray(star_x_cpu)
    star_y_gpu = CUDA.CuArray(star_y_cpu)
    star_z_gpu = CUDA.CuArray(star_z_cpu)
    star_speed_gpu = CUDA.CuArray(star_speed_cpu)
    star_phase_gpu = CUDA.CuArray(star_phase_cpu)
    star_size_gpu = CUDA.CuArray(star_size_cpu)
end

# Observables (CPU arrays used by Makie)
X_obs = Observable(X0)
Y_obs = Observable(Y0)
Z_obs = Observable(Z0)
C_obs = Observable(C0)

star_x_obs = Observable(star_x_cpu)
star_y_obs = Observable(star_y_cpu)
star_z_obs = Observable(star_z_cpu)
star_size_obs = Observable(star_size_cpu)
star_halo_size_obs = Observable(star_size_cpu .* 2.6f0)

alpha_init = clamp.(0.30f0 .* (0.6f0 .+ 0.4f0 .* sin.(0f0 .+ star_phase_cpu)) .+ 0.15f0, 0.05f0, 1f0)
star_core_colors_obs = Observable([RGBA{Float32}(1f0,1f0,1f0,a) for a in alpha_init])
star_halo_colors_obs = Observable([RGBA{Float32}(1f0,1f0,1f0,a*0.28f0) for a in alpha_init])

# Build a single Figure and axes (figure resolution is the place to set output size)
fig = Figure(resolution = size_px, backgroundcolor = RGB{Float32}(0f0,0f0,0f0))
label = Label(fig[1, 1:2], "frame 0/0"; fontsize = 18, halign = :left, tellwidth = false,
              color = RGBA{Float32}(1f0,1f0,1f0,1f0), padding = (6,6,6,6))

ax1 = Axis3(fig[2,1]; xlabel="X", ylabel="Y", zlabel="Z")
ax2 = Axis3(fig[2,2]; xlabel="X", ylabel="Y", zlabel="Z")
style_axis!(ax1); style_axis!(ax2)

# ---------- ADJUSTED axis limits (smaller box to match scaled flower) ----------
xlims!(ax1, -2f0, 2f0); ylims!(ax1, -2f0, 2f0); zlims!(ax1, -0.8f0, 2f0)
xlims!(ax2, -2f0, 2f0); ylims!(ax2, -2f0, 2f0); zlims!(ax2, -0.8f0, 2f0)

# create surfaces & scatter once using Observables
surface!(ax1, X_obs, Y_obs, Z_obs; color = C_obs, colormap = c_left_cs, shading = true)
surface!(ax2, X_obs, Y_obs, Z_obs; color = C_obs, colormap = c_right_cs, shading = true)

scatter!(ax1, star_x_obs, star_y_obs, star_z_obs; markersize = star_halo_size_obs, color = star_halo_colors_obs, transparency = true)
scatter!(ax1, star_x_obs, star_y_obs, star_z_obs; markersize = star_size_obs,      color = star_core_colors_obs, transparency = true)

scatter!(ax2, star_x_obs, star_y_obs, star_z_obs; markersize = star_halo_size_obs, color = star_halo_colors_obs, transparency = true)
scatter!(ax2, star_x_obs, star_y_obs, star_z_obs; markersize = star_size_obs,      color = star_core_colors_obs, transparency = true)

# ---------- camera params used each frame ----------
# base eye_dir set for 45° elevation and 45° azimuth
eye_dir = Float32[cos(cam_base_az)*cos(cam_elevation),
                  sin(cam_base_az)*cos(cam_elevation),
                  sin(cam_elevation)]
eye_dist_start = 2.2f0
eye_dist_end   = 1.8f0
lookat_pos = (0f0, 0f0, 0f0)
attraction = 0.990f0

@info "Recording $frames frames directly into MP4 (no PNGs)..."
start_time = now()

# === FIXED RECORD CALL: do NOT pass `resolution=` here — figure already has resolution ===
try
    GLMakie.record(fig, outfile_mp4, 1:frames; framerate = fps) do i
        t = Float32((i-1) / (frames-1))
        se = ease(t)

        # morph params
        ppr = lerp(ppr_range[1], ppr_range[2], se)
        pf  = lerp(pf_range[1],  pf_range[2],  se)
        ps  = lerp(ps_range[1],  ps_range[2],  se)
        ol_start = lerp(ol_start_range[1], ol_start_range[2], se)
        ol_end   = lerp(ol_end_range[1], ol_end_range[2], se)
        ol = (ol_start, ol_end)

        # compute geometry (GPU if available), collect once to CPU
        Xg, Yg, Zg, Cg = compute_geometry_gpu(ppr, pf, ps, ol)
        Xcpu = use_cuda ? Array(Xg) : Xg
        Ycpu = use_cuda ? Array(Yg) : Yg
        Zcpu = use_cuda ? Array(Zg) : Zg
        Ccpu = use_cuda ? Array(Cg) : Cg

        # ---------- NEW: scale the geometry each frame ----------
        Xcpu .*= flower_scale
        Ycpu .*= flower_scale
        Zcpu .*= flower_scale
        Ccpu .*= flower_scale

        # update surface Observables
        X_obs[] = Xcpu
        Y_obs[] = Ycpu
        Z_obs[] = Zcpu
        C_obs[] = Ccpu

        # camera & slow spin
        eye_dist = lerp(eye_dist_start, eye_dist_end, ease(se))
        max_total_rotation = 0.12f0
        az = max_total_rotation * se
        c = cos(az); s = sin(az)
        rotz = Float32[ c  -s  0.0;
                         s   c  0.0;
                         0.0 0.0 1.0 ]
        # rotate the base eye_dir to keep subtle rotation while preserving 45° elevation
        eye_vec = rotz * eye_dir * eye_dist
        eye_pos = (eye_vec[1], eye_vec[2], eye_vec[3])

        cam3d!(ax1.scene); cam3d!(ax2.scene)
        cam1 = cameracontrols(ax1.scene)
        cam1.lookat[] = lookat_pos
        cam1.eyeposition[] = eye_pos
        update_cam!(ax1.scene, cam1)
        cam2 = cameracontrols(ax2.scene)
        cam2.lookat[] = lookat_pos
        cam2.eyeposition[] = eye_pos
        update_cam!(ax2.scene, cam2)

        # update stars (GPU or CPU)
        if use_cuda
            # vectorized GPU updates (no scalar indexing)
            star_z_gpu .-= star_speed_gpu
            star_x_gpu .*= attraction
            star_y_gpu .*= attraction

            # mask of stars to respawn
            mask = star_z_gpu .< -0.6f0

            if any(mask)
                # generate replacement values on GPU in one shot
                new_z = 0.8f0 .+ 2.2f0 .* CUDA.rand(Float32, nstars)
                new_x = -2.2f0 .+ 4.4f0 .* CUDA.rand(Float32, nstars)
                new_y = -2.2f0 .+ 4.4f0 .* CUDA.rand(Float32, nstars)
                new_speed = 0.008f0 .+ (0.032f0 - 0.008f0) .* CUDA.rand(Float32, nstars)
                new_phase = 2f0 * Float32(pi) .* CUDA.rand(Float32, nstars)
                new_size = 2f0 .+ 4f0 .* CUDA.rand(Float32, nstars)

                star_z_gpu .= ifelse.(mask, new_z, star_z_gpu)
                star_x_gpu .= ifelse.(mask, new_x, star_x_gpu)
                star_y_gpu .= ifelse.(mask, new_y, star_y_gpu)
                star_speed_gpu .= ifelse.(mask, new_speed, star_speed_gpu)
                star_phase_gpu .= ifelse.(mask, new_phase, star_phase_gpu)
                star_size_gpu .= ifelse.(mask, new_size, star_size_gpu)
            end

            tw_gpu = @. 0.6f0 + 0.4f0 * sin(2.5f0 * Float32(pi) * (t * 3f0 + star_phase_gpu))
            dist_factor_gpu = clamp.(1f0 .- (abs.(star_z_gpu) ./ 6f0), 0.2f0, 1f0)
            alpha_vals_gpu = clamp.(0.30f0 .* tw_gpu .* dist_factor_gpu .+ 0.15f0, 0.05f0, 1f0)

            # collect once to CPU for plotting
            star_x_cpu = Array(star_x_gpu)
            star_y_cpu = Array(star_y_gpu)
            star_z_cpu = Array(star_z_gpu)
            star_size_cpu = Array(star_size_gpu)
            alpha_vals = Array(alpha_vals_gpu)
        else
            star_z_cpu .-= star_speed_cpu
            star_x_cpu .*= attraction
            star_y_cpu .*= attraction
            for j in 1:nstars
                if star_z_cpu[j] < -0.6f0
                    star_z_cpu[j] = Float32(rand(rng, Uniform(0.8, 3.0)))
                    star_x_cpu[j] = Float32(rand(rng, Uniform(-2.2, 2.2)))
                    star_y_cpu[j] = Float32(rand(rng, Uniform(-2.2, 2.2)))
                    star_speed_cpu[j] = Float32(rand(rng, Uniform(0.008, 0.032)))
                    star_phase_cpu[j] = Float32(rand(rng, Uniform(0.0, 2pi)))
                    star_size_cpu[j] = Float32(rand(rng, Uniform(2.0, 6.0)))
                end
            end
            tw = @. 0.6f0 + 0.4f0 * sin(2.5f0 * Float32(pi) * (t * 3f0 + star_phase_cpu))
            dist_factor = clamp.(1f0 .- (abs.(star_z_cpu) ./ 6f0), 0.2f0, 1f0)
            alpha_vals = clamp.(0.30f0 .* tw .* dist_factor .+ 0.15f0, 0.05f0, 1f0)
        end

        # update star Observables
        star_x_obs[] = star_x_cpu
        star_y_obs[] = star_y_cpu
        star_z_obs[] = star_z_cpu
        star_size_obs[] = star_size_cpu
        star_halo_size_obs[] = star_size_cpu .* 2.6f0
        star_core_colors_obs[] = [RGBA{Float32}(1f0,1f0,1f0,a) for a in alpha_vals]
        star_halo_colors_obs[] = [RGBA{Float32}(1f0,1f0,1f0,a*0.28f0) for a in alpha_vals]

        # update label text
        label.text = @sprintf("frame %3d/%3d  ppr=%.3f pf=%.3f ps=%.3f", i, frames, Float32(ppr), Float32(pf), Float32(ps))
    end
    @info "Recording finished."
catch e
    @error "Recording to MP4 failed: $e"
    rethrow(e)
end

elapsed = now() - start_time
@info "Finished in $(Dates.value(elapsed)/1e9) seconds."

# Build GIF from MP4 (optional)
if isfile(outfile_mp4)
    gif_fps = min(fps, 15)
    palette_file = "palette.png"
    gif_outfile = replace(outfile_mp4, ".mp4" => ".gif")
    run(`ffmpeg -y -i $outfile_mp4 -vf "fps=$gif_fps,scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=lanczos,palettegen" $palette_file`)
    run(`ffmpeg -y -i $outfile_mp4 -i $palette_file -filter_complex "fps=$gif_fps,scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=lanczos[x];[x][1:v]paletteuse" -loop 0 $gif_outfile`)
    @info "Saved GIF: $gif_outfile"
end
