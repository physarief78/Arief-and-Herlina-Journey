using GLMakie
using Makie
using ColorSchemes
using Colors
using FileIO
using Printf
using Dates
using LinearAlgebra
using Random
using Distributions

# ---------------- user settings ----------------
outfile_mp4 = "flower_animation_glmakie_with_stars.mp4"
fps = 24
duration_sec = 30
frames = fps * duration_sec
size_px = (1280, 720) # <-- Set to 1080p
frame_dir = "frames_glmakie"
mkpath(frame_dir)

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
    RGB{Float32}(Float32(0.02), Float32(0.03), Float32(0.15)),
    RGB{Float32}(Float32(0.0),  Float32(0.25), Float32(0.9)),
    RGB{Float32}(Float32(0.35), Float32(0.7),  Float32(1.0)),
    RGB{Float32}(Float32(0.9),  Float32(0.95), Float32(1.0))
])
c_right_cs = reverse(ColorSchemes.hot)

# helpers
lerp(a,b,t) = a + (b-a)*t
ease(t::Float32) = Float32(0.5) * (Float32(1.0) - cos(Float32(pi) * t))

# geometry
function compute_geometry(ppr::Float32, pf::Float32, ps::Float32, ol_range::Tuple{Float32,Float32})
    pt = (Float32(1.0) / ppr) * (Float32(2.0) * Float32(pi))
    θ = range(Float32(0.0), stop = Float32(pn) * pt, length = pn * pr + 1)
    r_vals = range(Float32(0.0), stop = Float32(1.0), length = nr)

    R = [Float32(r) for r in r_vals, _ in θ]
    THETA = [Float32(t) for _ in r_vals, t in θ]

    x = Float32.(1.0) .- (((ps .* ((Float32(1.0) .- mod.(ppr .* THETA, Float32(2pi)) ./ Float32(pi)).^2) .- Float32(1.0)/Float32(4.0)).^2) ./ Float32(2.0))

    phi_vec = (Float32(pi)/Float32(2.0)) .* (range(ol_range[1], stop = ol_range[2], length = pn * pr + 1) .^ 2)
    sin_phi = sin.(phi_vec')
    cos_phi = cos.(phi_vec')

    y = pf .* (R.^2) .* ((Float32(1.28) .* R .- Float32(1.0)).^2) .* sin_phi
    R2 = (x .* (R .* sin_phi)) .+ (y .* cos_phi)
    X = R2 .* sin.(THETA)
    Y = R2 .* cos.(THETA)
    Z = x .* ((R .* cos_phi) .- (y .* sin_phi))
    C = sqrt.(X.^2 .+ Y.^2 .+ Z.^2)

    return (Float32.(X), Float32.(Y), Float32.(Z), Float32.(C))
end

# style helper (hide ticks, keep labels)
function style_axis!(ax)
    ax.scene.backgroundcolor[] = RGB{Float32}(Float32(0.0), Float32(0.0), Float32(0.0))
    ax.xgridvisible = false
    ax.ygridvisible = false
    ax.zgridvisible = false
    ax.xticksvisible = false
    ax.yticksvisible = false
    ax.zticksvisible = false
    ax.xlabelcolor[] = RGBA{Float32}(Float32(1.0), Float32(1.0), Float32(1.0), Float32(1.0))
    ax.ylabelcolor[] = RGBA{Float32}(Float32(1.0), Float32(1.0), Float32(1.0), Float32(1.0))
    ax.zlabelcolor[] = RGBA{Float32}(Float32(1.0), Float32(1.0), Float32(1.0), Float32(1.0))
    return nothing
end

@info "Rendering $frames frames to '$frame_dir'..."
start_time = now()

# camera
v = Float32[1.0, 1.0, 0.6]
eye_dir = v / sqrt(sum(v .* v))
eye_dist_start = Float32(2.2)
eye_dist_end   = Float32(1.8)
lookat_pos = (Float32(0.0), Float32(0.0), Float32(0.0))

# ---------- STARS: more visible + twinkle glow ----------
rng = MersenneTwister(12345)
nstars = 320

# spawn stars a little closer so they're readable in the zoomed view
star_x = Float32.(rand(rng, Uniform(-2.2, 2.2), nstars))
star_y = Float32.(rand(rng, Uniform(-2.2, 2.2), nstars))
star_z = Float32.(rand(rng, Uniform(0.8, 3.0), nstars))   # closer top range

# speeds (a bit faster variation so motion is visible)
star_speed = Float32.(rand(rng, Uniform(0.008, 0.032), nstars))

# phases and sizes (increase base size slightly)
star_phase = Float32.(rand(rng, Uniform(0.0, 2pi), nstars))
star_size  = Float32.(rand(rng, Uniform(2.0, 6.0), nstars))  # larger sizes for visibility

# weaker attraction so they don't collapse to center too quickly
attraction = Float32(0.990)

for i in 1:frames
    t = Float32((i-1) / (frames-1))
    se = ease(t)

    # morph params
    ppr = lerp(ppr_range[1], ppr_range[2], se)
    pf  = lerp(pf_range[1],  pf_range[2],  se)
    ps  = lerp(ps_range[1],  ps_range[2],  se)
    ol_start = lerp(ol_start_range[1], ol_start_range[2], se)
    ol_end   = lerp(ol_end_range[1], ol_end_range[2], se)
    ol = (ol_start, ol_end)

    X, Y, Z, C = compute_geometry(ppr, pf, ps, ol)

    # camera & slow spin
    eye_dist = lerp(eye_dist_start, eye_dist_end, ease(se))
    max_total_rotation = Float32(0.12)
    az = max_total_rotation * se
    c = cos(az); s = sin(az)
    rotz = Float32[ c  -s  0.0;
                     s   c  0.0;
                     0.0 0.0 1.0 ]
    eye_vec = rotz * eye_dir * eye_dist
    eye_pos = (Float32(eye_vec[1]), Float32(eye_vec[2]), Float32(eye_vec[3]))

    # build figure
    # NOTE: use `size=` (not `resolution=`) to avoid deprecation warning
    fig = Figure(size = size_px, backgroundcolor = RGB{Float32}(Float32(0.0),Float32(0.0),Float32(0.0)))
    frametext = @sprintf("frame %3d/%3d  ppr=%.3f pf=%.3f ps=%.3f", i, frames, Float32(ppr), Float32(pf), Float32(ps))
    Label(fig[1, 1:2], frametext; fontsize = 18, halign = :left, tellwidth = false,
          color = RGBA{Float32}(Float32(1.0),Float32(1.0),Float32(1.0),Float32(1.0)), padding = (6,6,6,6))

    ax1 = Axis3(fig[2,1]; xlabel="X", ylabel="Y", zlabel="Z")
    ax2 = Axis3(fig[2,2]; xlabel="X", ylabel="Y", zlabel="Z")
    style_axis!(ax1); style_axis!(ax2)

    # reduced z-range (shorter height) for composition
    xlims!(ax1, Float32(-3.0), Float32(3.0))
    ylims!(ax1, Float32(-3.0), Float32(3.0))
    zlims!(ax1, Float32(-1.0), Float32(3.0))
    xlims!(ax2, Float32(-3.0), Float32(3.0))
    ylims!(ax2, Float32(-3.0), Float32(3.0))
    zlims!(ax2, Float32(-1.0), Float32(3.0))

    # flower surfaces
    # NOTE: replace `shading = true` (invalid) with a valid shading mode
    surface!(ax1, X, Y, Z; color = C, colormap = c_left_cs, shading = Makie.automatic)
    surface!(ax2, X, Y, Z; color = C, colormap = c_right_cs, shading = Makie.automatic)

    # update star motion
    star_z .-= star_speed
    star_x .*= attraction
    star_y .*= attraction

    # respawn stars that passed below threshold: respawn a bit closer top so visible
    for j in 1:nstars
        if star_z[j] < -0.6f0
            star_z[j] = Float32(rand(rng, Uniform(0.8, 3.0)))    # respawn closer
            star_x[j] = Float32(rand(rng, Uniform(-2.2, 2.2)))
            star_y[j] = Float32(rand(rng, Uniform(-2.2, 2.2)))
            star_speed[j] = Float32(rand(rng, Uniform(0.008, 0.032)))
            star_phase[j] = Float32(rand(rng, Uniform(0.0, 2pi)))
            star_size[j] = Float32(rand(rng, Uniform(2.0, 6.0)))
        end
    end

    # stronger twinkle: higher baseline + larger amplitude, slightly faster frequency
    # tw in [0.2 .. 1.0+] depending on phase
    tw = @. Float32(0.6) + Float32(0.4) * sin(Float32(2.5) * Float32(pi) * (t * Float32(3.0) + star_phase))

    # distance-based dimmer (clamped)
    dist_factor = clamp.(Float32(1.0) .- (abs.(star_z) ./ Float32(6.0)), Float32(0.2), Float32(1.0))

    # brighter base alpha and stronger modulation so sparkles are noticeable
    alpha_vals = Float32.(Float32(0.30) .* tw .* dist_factor .+ Float32(0.15))   # base up from 0.15 -> more visible
    # clamp to 0..1 defensively
    alpha_vals = clamp.(alpha_vals, Float32(0.05), Float32(1.0))

    # core colors (white)
    star_core_colors = [RGBA{Float32}(Float32(1.0), Float32(1.0), Float32(1.0), a) for a in alpha_vals]

    # halo: slightly larger, lower-alpha white for glow
    halo_alpha = Float32.(alpha_vals .* Float32(0.28))   # about 25-30% of core alpha
    star_halo_colors = [RGBA{Float32}(Float32(1.0), Float32(1.0), Float32(1.0), a) for a in halo_alpha]
    star_halo_size = star_size .* Float32(2.6)   # soft glow behind each core

    # draw halo first (bigger, fainter), then core (smaller, brighter)
    scatter!(ax1, star_x, star_y, star_z; markersize = star_halo_size, color = star_halo_colors, transparency = true)
    scatter!(ax1, star_x, star_y, star_z; markersize = star_size, color = star_core_colors, transparency = true)

    scatter!(ax2, star_x, star_y, star_z; markersize = star_halo_size, color = star_halo_colors, transparency = true)
    scatter!(ax2, star_x, star_y, star_z; markersize = star_size, color = star_core_colors, transparency = true)

    # camera
    cam3d!(ax1.scene); cam3d!(ax2.scene)
    cam1 = cameracontrols(ax1.scene)
    cam1.lookat[] = lookat_pos
    cam1.eyeposition[] = eye_pos
    update_cam!(ax1.scene, cam1)
    cam2 = cameracontrols(ax2.scene)
    cam2.lookat[] = lookat_pos
    cam2.eyeposition[] = eye_pos
    update_cam!(ax2.scene, cam2)

    # save frame
    fname = joinpath(frame_dir, @sprintf("frame_%04d.png", i))

    # ----------------------------------------------------------------
    # THE FIX (Solution 1) IS HERE:
    # We explicitly tell `save` the resolution to use,
    # overriding any defaults.
    save(fname, fig, size = size_px)
    # ----------------------------------------------------------------

    fig = nothing
    if i % 12 == 0
        GC.gc()
    end
    if (i % 12 == 0) || (i == frames)
        @info "Saved frame $i / $frames -> $fname"
    end
end

elapsed = now() - start_time
@info "Rendered $frames frames in $(Dates.value(elapsed)/1e9) seconds (wall time)."

# ffmpeg assembly (same as before)
ffmpeg_cmd_mp4 = `ffmpeg -y -framerate $fps -i $(joinpath(frame_dir,"frame_%04d.png")) -c:v libx264 -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" $outfile_mp4`
@info "Running ffmpeg to build MP4..."
run(ffmpeg_cmd_mp4)
@info "Saved MP4: $outfile_mp4"

gif_fps = min(fps, 15)
palette_file = joinpath(frame_dir, "palette.png")
gif_outfile = replace(outfile_mp4, ".mp4" => ".gif")

palette_cmd = `ffmpeg -y -i $outfile_mp4 -vf "fps=$gif_fps,scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=lanczos,palettegen" $palette_file`
@info "Generating GIF palette..."
run(palette_cmd)

gif_cmd = `ffmpeg -y -i $outfile_mp4 -i $palette_file -filter_complex "fps=$gif_fps,scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=lanczos[x];[x][1:v]paletteuse" -loop 0 $gif_outfile`
@info "Building GIF..."
run(gif_cmd)

@info "Saved GIF: $gif_outfile (palette: $palette_file)"
