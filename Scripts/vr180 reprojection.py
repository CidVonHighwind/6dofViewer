import cv2 as cv
import numpy as np
import os
import glob
import sys
from dataclasses import dataclass


@dataclass
class Projection:
    fov_h: int
    fov_v: int
    pitch_deg: int
    yaw_deg: int

# output projections
projections = [
    # Projection(132, 60, 40, 0),
    # Projection(132, 60, 0, 0),
    # Projection(132, 60, -40, 0),
    Projection(90, 90, 0, 0),
]

def main():
    if len(sys.argv) < 2:
        print("folder path is missing")
        sys.exit(1)

    folder_path = sys.argv[1]
    folder_path_out = folder_path + "\\out"

    # parse output size
    out_size = 1800
    if len(sys.argv) >= 3:
        out_size = int(sys.argv[2])

    # create output folder
    if not os.path.exists(folder_path_out):
        os.makedirs(folder_path_out)

    # Find all .jpg and .png files
    image_paths = (
        glob.glob(os.path.join(folder_path, "*.jpg"))
        + glob.glob(os.path.join(folder_path, "*.jpeg"))
        + glob.glob(os.path.join(folder_path, "*.png"))
    )

    # Iterate through each image path
    for index, image_path in enumerate(image_paths):
        file_name = os.path.basename(image_path)
        name_without_extension, _ = os.path.splitext(file_name)
        file_index = int(name_without_extension)

        print(f"Processing image: {image_path}")

        eq_img = cv.imread(image_path)
        h, w = eq_img.shape[:2]

        for projection in projections:
            persp_view_l = equirectangular_to_perspective(
                eq_img[0:h, 0 : int(w / 2)],
                fov_deg=projection.fov_h,
                fov_deg_v=projection.fov_v,
                pitch_deg=projection.pitch_deg,
                yaw_deg=projection.yaw_deg,
                out_size=(out_size, out_size)
            )
            persp_view_r = equirectangular_to_perspective(
                eq_img[0:h, int(w / 2) : w],
                fov_deg=projection.fov_h,
                fov_deg_v=projection.fov_v,
                pitch_deg=projection.pitch_deg,
                yaw_deg=projection.yaw_deg,
                out_size=(out_size, out_size)
            )

            cv.imwrite(
                f"{folder_path_out}\\{file_index} {projection.fov_h} {projection.fov_v} {projection.pitch_deg} {projection.yaw_deg} l.png",
                persp_view_l,
            )
            cv.imwrite(
                f"{folder_path_out}\\{file_index} {projection.fov_h} {projection.fov_v} {projection.pitch_deg} {projection.yaw_deg} r.png",
                persp_view_r,
            )


def equirectangular_to_perspective(
    equirect_img,
    fov_deg=90,
    fov_deg_v=90,
    pitch_deg=0,
    yaw_deg=0,
    out_size=(2560, 2560),
):
    """
    Projects an equirectangular image into a perspective view.

    Parameters:
        equirect_img: HxWx3 equirectangular image
        fov_deg: field of view in degrees (horizontal)
        pitch_deg: vertical angle in degrees (up/down)
        yaw_deg: horizontal angle in degrees (left/right)
        out_size: output resolution (width, height)
    """
    h, w = out_size
    fov = np.radians(fov_deg)
    pitch = np.radians(pitch_deg)
    yaw = np.radians(yaw_deg)

    # Field of view parameters
    fx = 0.5 * w / np.tan(fov / 2)
    fy = 0.5 * w / np.tan(np.radians(fov_deg_v) / 2)

    # Create pixel coordinate grid
    x = np.arange(w)
    y = np.arange(h)
    x, y = np.meshgrid(x, y)

    x = (x - w / 2) / fx
    y = (y - h / 2) / fy
    z = np.ones_like(x)

    # Normalize vectors
    norm = np.sqrt(x**2 + y**2 + z**2)
    x /= norm
    y /= norm
    z /= norm

    # Apply rotation
    Rx = np.array(
        [
            [1, 0, 0],
            [0, np.cos(pitch), -np.sin(pitch)],
            [0, np.sin(pitch), np.cos(pitch)],
        ]
    )
    Ry = np.array(
        [[np.cos(yaw), 0, np.sin(yaw)], [0, 1, 0], [-np.sin(yaw), 0, np.cos(yaw)]]
    )
    R = Ry @ Rx

    coords = np.stack([x, y, z], axis=-1)
    coords = coords @ R.T

    lon = np.arctan2(coords[..., 0], coords[..., 2])
    lat = np.arcsin(coords[..., 1])

    # Map to equirectangular image
    eq_h, eq_w = equirect_img.shape[:2]
    u = (lon / np.pi + 0.5) * eq_w
    v = eq_h - (0.5 - lat / np.pi) * eq_h

    map_x = u.astype(np.float32)
    map_y = v.astype(np.float32)

    perspective = cv.remap(
        equirect_img,
        map_x,
        map_y,
        interpolation=cv.INTER_LINEAR,
        borderMode=cv.BORDER_CONSTANT,
    )

    aspect_ratio = np.tan(np.radians(fov_deg) / 2) / np.tan(np.radians(fov_deg_v) / 2)
    new_width = perspective.shape[0]
    new_height = int(perspective.shape[1] / aspect_ratio)

    resized = cv.resize(
        perspective, (new_width, new_height), interpolation=cv.INTER_AREA
    )

    return resized


if __name__ == "__main__":
    main()