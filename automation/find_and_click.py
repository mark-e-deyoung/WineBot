#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys
import tempfile
import time

import cv2


def capture_screenshot(display_value, output_path):
    result = subprocess.run(
        ["import", "-display", display_value, "-window", "root", output_path],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "Failed to capture screenshot")


def load_image(image_path, error_label):
    image = cv2.imread(image_path)
    if image is None:
        raise RuntimeError(f"Unable to load {error_label} from {image_path}")
    return image


def click_coordinates(x_coord, y_coord):
    subprocess.run(
        ["xdotool", "mousemove", "--sync", str(x_coord), str(y_coord), "click", "1"],
        check=True,
    )


def find_and_click(
    template_path,
    display_value,
    threshold_value,
    retries,
    delay_seconds,
    screenshot_out,
):
    template = load_image(template_path, "template")
    temporary_path = None
    if screenshot_out is None:
        temp_file = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
        temporary_path = temp_file.name
        temp_file.close()
        screenshot_out = temporary_path

    try:
        for attempt_index in range(retries):
            capture_screenshot(display_value, screenshot_out)
            screenshot = load_image(screenshot_out, "screenshot")
            result = cv2.matchTemplate(screenshot, template, cv2.TM_CCOEFF_NORMED)
            _, max_value, _, max_location = cv2.minMaxLoc(result)
            if max_value >= threshold_value:
                template_height, template_width = template.shape[:2]
                center_x = max_location[0] + template_width // 2
                center_y = max_location[1] + template_height // 2
                click_coordinates(center_x, center_y)
                return True
            if attempt_index < retries - 1:
                time.sleep(delay_seconds)
        return False
    finally:
        if temporary_path is not None:
            os.unlink(temporary_path)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--template", required=True)
    parser.add_argument("--threshold", type=float, default=0.8)
    parser.add_argument("--retries", type=int, default=5)
    parser.add_argument("--delay", type=float, default=1.0)
    parser.add_argument("--display", default=os.environ.get("DISPLAY", ":99"))
    parser.add_argument("--screenshot-out")
    return parser.parse_args()


def main():
    args = parse_args()
    try:
        found = find_and_click(
            template_path=args.template,
            display_value=args.display,
            threshold_value=args.threshold,
            retries=args.retries,
            delay_seconds=args.delay,
            screenshot_out=args.screenshot_out,
        )
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0 if found else 2


if __name__ == "__main__":
    sys.exit(main())

