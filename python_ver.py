
"""
make_flower_mp4.py

Creates an MP4 animation from the Julia-style surface code supplied.
Backwards-compatible removal of old Matplotlib surface collections is used
so this works on older Matplotlib versions as well.

Usage:
    python make_flower_mp4.py
    python make_flower_mp4.py --frames 120 --fps 30 --dpi 120 --cleanup

"""

import os
import argparse
import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt
import imageio
from tqdm import tqdm

# -----------------------
# Default parameters (exactly as you provided)
# -----------------------
ppr = 3.6
nr  = 30
pr  = 30
pn  = 40
pf  = 2.0
ps  = 5.0/4.0
ol0 = 0.2
ol1 = 1.02

def build_parser():
    p = argparse.ArgumentParser(description="Render flower surfaces and compose MP4")
    p.add_argument("--out", "-o", default="Selamat_Ulang_Tahun_Erlin.mp4", help="Output mp4 filename")
    p.add_argument("--frames", type=int, default=120, help="Number of frames to render")
    p.add_argument("--fps", type=int, default=30, help="Frames per second for output")
    p.add_argument("--dpi", type=int, default=120, help="DPI when saving frames")
    p.add_argument("--figsize", type=float, nargs=2, default=(10, 5), help="Figure size (inches) as two numbers: W H")
    p.add_argument("--outdir", default="frames_flower", help="Temporary frames directory")
    p.add_argument("--cleanup", action="store_true", help="Delete frame PNGs after composing movie")
    p.add_argument("--subsample_theta", type=int, default=1, help="Subsample theta by this factor (1 = full resolution). Use >1 to speed up.")
    return p

def compute_mesh(ppr, ps, pf, R, THETA, ol_low, ol_high):
    # phi vector length should match THETA's second axis
    phi_vec = (np.pi / 2.0) * (np.linspace(ol_low, ol_high, THETA.shape[1]) ** 2)
    sin_phi = np.sin(phi_vec)[np.newaxis, :]
    cos_phi = np.cos(phi_vec)[np.newaxis, :]

    mod_term = np.mod(ppr * THETA, 2.0 * np.pi)
    x = 1.0 - (((ps * ((1.0 - mod_term / np.pi) ** 2) - 0.25) ** 2) / 2.0)

    y = pf * (R ** 2) * ((1.28 * R - 1.0) ** 2) * sin_phi
    R2 = (x * (R * sin_phi)) + (y * cos_phi)

    X = R2 * np.sin(THETA)
    Y = R2 * np.cos(THETA)
    Z = x * ((R * cos_phi) - (y * sin_phi))
    C = np.sqrt(X ** 2 + Y ** 2 + Z ** 2)
    return X, Y, Z, C

def safe_clear_collections(ax):
    """
    Remove previous artists/collections from a 3D Axes in a way that works
    across Matplotlib versions (older versions may not have .clear()).
    """
    try:
        # Remove items one by one
        while len(ax.collections) > 0:
            del ax.collections[0]
    except Exception:
        # As a last resort, try replacing with a new empty list (some Matplotlib versions
        # may resist direct deletion; this fallback is rarely needed)
        try:
            ax.collections = []
        except Exception:
            pass

def draw_surface(ax, X, Y, Z, C, cmap):
    # Remove previous surface collections safely
    safe_clear_collections(ax)

    norm = mpl.colors.Normalize(vmin=np.nanmin(C), vmax=np.nanmax(C))
    facecolors = cmap(norm(C))
    surf = ax.plot_surface(X, Y, Z, rstride=1, cstride=1,
                           facecolors=facecolors, linewidth=0,
                           antialiased=False, shade=False)
    return surf

def style_axis(ax):
    # Make axis background black and labels white as in your HTML layout
    try:
        ax.set_facecolor('black')
    except Exception:
        pass
    ax.xaxis.label.set_color('white')
    ax.yaxis.label.set_color('white')
    ax.zaxis.label.set_color('white')
    ax.tick_params(colors='white', which='both', labelsize=9)
    ax.set_xlabel("X")
    ax.set_ylabel("Y")
    ax.set_zlabel("Z")
    ax.grid(True, color='gray', linewidth=0.4)
    try:
        ax.set_box_aspect((1,1,0.6))
    except Exception:
        pass

def main():
    parser = build_parser()
    args = parser.parse_args()

    OUT_DIR = args.outdir
    os.makedirs(OUT_DIR, exist_ok=True)

    # theta and R grid
    pt = (1.0 / ppr) * 2.0 * np.pi
    theta_full = np.linspace(0.0, pn * pt, pn * pr + 1)
    if args.subsample_theta >= 2:
        theta = theta_full[::args.subsample_theta]
    else:
        theta = theta_full
    theta_len = len(theta)
    r_vals = np.linspace(0.0, 1.0, nr)
    R, THETA = np.meshgrid(r_vals, theta, indexing='ij')  # shape (nr, theta_len)

    # colormaps
    cmap1 = mpl.colors.LinearSegmentedColormap.from_list("blue_violet", ["blue", "violet"])
    cmap2 = plt.cm.get_cmap("hot").reversed()

    # render frames
    print(f"Rendering {args.frames} frames to directory: {OUT_DIR}")
    for i in tqdm(range(args.frames), desc="rendering frames"):
        t = i / float(args.frames)
        ol_low = ol0 + 0.12 * np.sin(2.0 * np.pi * t)
        ol_high = ol1 + 0.12 * np.cos(2.0 * np.pi * t)

        X, Y, Z, C = compute_mesh(ppr, ps, pf, R, THETA, ol_low, ol_high)

        fig = plt.figure(figsize=tuple(args.figsize), dpi=args.dpi)
        fig.patch.set_facecolor('black')

        ax1 = fig.add_subplot(1, 2, 1, projection='3d')
        ax2 = fig.add_subplot(1, 2, 2, projection='3d')

        style_axis(ax1)
        style_axis(ax2)

        # camera rotation for dynamics
        azim = 30 + 140 * t
        elev = 25 + 8 * np.sin(2 * np.pi * t)
        ax1.view_init(elev=elev, azim=azim)
        ax2.view_init(elev=elev, azim=azim + 10)

        draw_surface(ax1, X, Y, Z, C, cmap1)
        draw_surface(ax2, X, Y, Z, C, cmap2)

        plt.tight_layout()
        fname = os.path.join(OUT_DIR, f"frame_{i:04d}.png")
        fig.savefig(fname, facecolor=fig.get_facecolor(), bbox_inches='tight', dpi=args.dpi)
        plt.close(fig)

    # collect frame filenames
    frame_files = [os.path.join(OUT_DIR, f) for f in sorted(os.listdir(OUT_DIR)) if f.endswith(".png")]
    if not frame_files:
        print("No frames found - aborting.")
        return

    # compose MP4 using imageio (ffmpeg backend if available)
    out_mp4 = args.out
    print("Composing movie:", out_mp4)
    try:
        writer = imageio.get_writer(out_mp4, fps=args.fps, codec='libx264', ffmpeg_params=['-pix_fmt', 'yuv420p'])
        for f in tqdm(frame_files, desc="writing mp4"):
            img = imageio.imread(f)
            writer.append_data(img)
        writer.close()
        print("Saved MP4 to:", out_mp4)
    except Exception as e:
        print("MP4 composition failed (ffmpeg may be missing). Error:", e)
        # fallback: try GIF
        out_gif = os.path.splitext(out_mp4)[0] + ".gif"
        try:
            images = [imageio.imread(f) for f in frame_files]
            imageio.mimsave(out_gif, images, fps=args.fps)
            print("Saved fallback GIF to:", out_gif)
        except Exception as e2:
            print("GIF fallback also failed:", e2)
            print("No movie produced.")

    # cleanup
    if args.cleanup:
        print("Cleaning up frame PNGs...")
        for f in frame_files:
            try:
                os.remove(f)
            except Exception:
                pass
        try:
            os.rmdir(OUT_DIR)
        except Exception:
            pass
        print("Cleanup complete.")

if __name__ == "__main__":
    main()
