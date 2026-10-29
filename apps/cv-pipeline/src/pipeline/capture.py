"""Video capture abstraction supporting file, RTSP, and test pattern sources."""

import cv2
import numpy as np
import time
import logging
from dataclasses import dataclass
from typing import Optional, Tuple

logger = logging.getLogger(__name__)

@dataclass
class Frame:
    """Single video frame with metadata."""
    image: cv2.Mat  # BGR numpy array
    timestamp: float  # time.time()
    frame_id: int

class VideoCapture:
    """
    Wrapper around cv2.VideoCapture with reconnect logic and metrics.

    Supports:
    - Local file: /path/to/video.mp4
    - RTSP stream: rtsp://user:pass@host:port/stream
    - Test pattern: solid color or moving bar (for local dev without camera)
    """

    def __init__(
        self,
        source: str,
        width: int = 640,
        height: int = 480,
        fps: int = 30,
        reconnect_attempts: int = 5,
        reconnect_delay: float = 2.0,
    ):
        self.source = source
        self.width = width
        self.height = height
        self.fps = fps
        self.reconnect_attempts = reconnect_attempts
        self.reconnect_delay = reconnect_delay

        self._cap: Optional[cv2.VideoCapture] = None
        self._frame_id = 0
        self._last_success = time.time()

        self._connect()

    def _connect(self) -> bool:
        """Attempt to open the video source."""
        if self._cap is not None:
            self._cap.release()

        logger.info(f"Connecting to video source: {self.source}")
        self._cap = cv2.VideoCapture(self.source)

        if not self._cap.isOpened():
            logger.warning(f"Failed to open {self.source}, trying test pattern")
            self._cap = self._create_test_pattern_capture()

        if self._cap.isOpened():
            # Set properties
            self._cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
            self._cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
            self._cap.set(cv2.CAP_PROP_FPS, self.fps)
            logger.info(f"Connected to {self.source} ({self.width}x{self.height}@{self.fps}fps)")
            return True
        else:
            logger.error(f"Cannot open video source: {self.source}")
            return False

    def _create_test_pattern_capture(self) -> cv2.VideoCapture:
        """Create a test pattern generator (solid color + moving bar)."""
        cap = cv2.VideoCapture(0)  # Dummy device
        # Override read() to generate frames
        original_read = cap.read
        def test_pattern_read():
            ret, frame = original_read()
            if not ret:
                # Generate test pattern
                frame = np.zeros((self.height, self.width, 3), dtype=np.uint8)
                frame[:] = [30, 30, 40]  # Dark blue-gray
                # Moving white bar
                pos = int((time.time() * 50) % self.width)
                frame[:, pos:pos+10] = [255, 255, 255]
                # Timestamp text
                cv2.putText(
                    frame,
                    f"TEST PATTERN {time.strftime('%H:%M:%S')}",
                    (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.7,
                    (0, 255, 255),
                    2
                )
                return True, frame
            return ret, frame
        cap.read = test_pattern_read  # type: ignore
        return cap

    def read(self) -> Tuple[bool, Optional[Frame]]:
        """
        Read next frame with automatic reconnect on failure.

        Returns:
            (success, frame) where frame is None if unsuccessful
        """
        if self._cap is None or not self._cap.isOpened():
            if not self._reconnect():
                return False, None

        ret, image = self._cap.read()
        if not ret or image is None:
            logger.warning("Failed to read frame, attempting reconnect")
            if not self._reconnect():
                return False, None
            # Try once more after reconnect
            ret, image = self._cap.read()
            if not ret or image is None:
                return False, None

        frame = Frame(
            image=image,
            timestamp=time.time(),
            frame_id=self._frame_id
        )
        self._frame_id += 1
        self._last_success = time.time()

        return True, frame

    def _reconnect(self) -> bool:
        """Attempt to reconnect to video source."""
        logger.info(f"Attempting reconnect to {self.source}")
        for attempt in range(self.reconnect_attempts):
            if self._connect():
                return True
            logger.warning(f"Reconnect attempt {attempt + 1} failed, retrying in {self.reconnect_delay}s...")
            time.sleep(self.reconnect_delay)
        return False

    def isOpened(self) -> bool:
        return self._cap is not None and self._cap.isOpened()

    def release(self):
        if self._cap is not None:
            self._cap.release()
            self._cap = None

    def __del__(self):
        self.release()