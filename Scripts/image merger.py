import cv2
import numpy as np
import time
import glob
import sys
import os
from dataclasses import dataclass


@dataclass
class FileInfo:
    path: str
    number: int
    fov_h: int
    fov_v: int
    pitch: int
    yaw: int
    eye: str


def main():
    if len(sys.argv) < 2:
        print("folder path is missing")
        sys.exit(1)

    folderPath = sys.argv[1]
    folderPathOut = folderPath + "\\merge\\"

    # create output folder
    if not os.path.exists(folderPathOut):
        os.makedirs(folderPathOut)

    start = time.perf_counter()

    image_paths = glob.glob(os.path.join(folderPath, "*.png"))

    fileInfos = []
    for path in image_paths:
        file_name = os.path.basename(path)
        name_without_extension, _ = os.path.splitext(file_name)
        number, fov_h, fov_v, pitch, yaw, eye = name_without_extension.split(" ")

        fileInfo = FileInfo(
            path, int(number), int(fov_h), int(fov_v), int(pitch), int(yaw), eye
        )
        fileInfos.append(fileInfo)

    for number in range(1, 100):
        merge_images(folderPathOut, fileInfos, number)

    end = time.perf_counter()
    print(f"Elapsed time: {end - start} seconds")


def merge_images(folderPathOut, fileInfos, number):
    left_images = [
        fileInfo
        for fileInfo in fileInfos
        if fileInfo.number == number and fileInfo.eye == "l"
    ]

    right_images = [
        fileInfo
        for fileInfo in fileInfos
        if fileInfo.number == number and fileInfo.eye == "r"
    ]

    for left, right in zip(left_images, right_images):
        left_img = cv2.imread(left.path, cv2.IMREAD_UNCHANGED)
        right_img = cv2.imread(right.path, cv2.IMREAD_UNCHANGED)

        merged_img = np.hstack((left_img, right_img))

        file_name = os.path.basename(left.path)
        name_without_extension, _ = os.path.splitext(file_name)
        cv2.imwrite(
            folderPathOut + name_without_extension.replace(" l", "") + ".png",
            merged_img,
        )


if __name__ == "__main__":
    main()
