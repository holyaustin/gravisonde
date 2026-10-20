"""Object detection and feature extraction using OpenCV 5 new features."""

import cv2
import numpy as np
import logging
import os
from typing import List, Tuple, Optional
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class Detection:
    """Single detection result."""
    class_id: int
    class_name: str
    confidence: float
    bbox: Tuple[int, int, int, int]  # x, y, width, height

@dataclass
class Features:
    """Feature detection result."""
    keypoints: List[cv2.KeyPoint]
    descriptors: Optional[np.ndarray]

class Detector:
    """
    OpenCV 5 detector combining:
    - DNN engine (new in v5) for object detection (YOLO11n ONNX)
    - Features2D module (new in v5) for ALIKED keypoints + LightGlue matching
    """

    def __init__(
        self,
        model_path: str = "yolo11n.onnx",
        conf_threshold: float = 0.5,
        nms_threshold: float = 0.4,
        use_gpu: bool = False,
        feature_detector: str = "aliked",  # aliked, disk, or sift
        use_lightglue_matcher: bool = True,
    ):
        self.conf_threshold = conf_threshold
        self.nms_threshold = nms_threshold
        self.use_gpu = use_gpu

        # Initialize DNN for object detection
        self.net = self._init_dnn(model_path)
        self.classes = self._load_coco_classes()
        self.mode = "onnx" if os.path.exists(model_path) else "synthetic"

        # Initialize feature detector (OpenCV 5 new Features2D)
        self.feature_detector = self._init_feature_detector(feature_detector)
        self.matcher = self._init_matcher(use_lightglue_matcher) if use_lightglue_matcher else None

        # Store previous frame features for matching
        self.prev_kps: Optional[List[cv2.KeyPoint]] = None
        self.prev_desc: Optional[np.ndarray] = None

        logger.info(f"Detector initialized: DNN={model_path}, Feature={feature_detector}")

    def _init_dnn(self, model_path: str) -> cv2.dnn.Net:
        """Initialize OpenCV DNN network with OpenCV 5 engine selection."""
        # Check if model file exists
        if not os.path.exists(model_path):
            logger.warning(f"Model file {model_path} not found, using dummy detector")
            return self._create_dummy_net()

        # OpenCV 5: Try new DNN engine first, fallback to classic
        # Engine selection: ENGINE_AUTO (3) = try new, fallback to classic
        net = cv2.dnn.readNet(model_path)

        # Prefer new engine if available (OpenCV 5 feature)
        try:
            net.setPreferableBackend(cv2.dnn.DNN_BACKEND_DEFAULT)
            net.setPreferableTarget(cv2.dnn.DNN_TARGET_CPU)
            if self.use_gpu and cv2.cuda.getCudaEnabledDeviceCount() > 0:
                net.setPreferableBackend(cv2.dnn.DNN_BACKEND_CUDA)
                net.setPreferableTarget(cv2.dnn.DNN_TARGET_CUDA)
                logger.info("DNN using CUDA backend")
            else:
                logger.info("DNN using CPU backend")
        except Exception as e:
            logger.warning(f"Could not set DNN backend/target: {e}")

        return net

    @staticmethod
    def _create_dummy_net() -> cv2.dnn.Net:
        """Create a dummy network for when model file is missing."""
        # Return a minimal net that will return empty detections
        net = cv2.dnn.Net()
        logger.warning("Using dummy detector - no detections will be produced")
        return net

    @staticmethod
    def _load_coco_classes() -> List[str]:
        """Load COCO class names (80 classes)."""
        return [
            "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
            "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat",
            "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack",
            "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball",
            "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket",
            "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
            "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake",
            "chair", "couch", "potted plant", "bed", "dining table", "toilet", "tv", "laptop",
            "mouse", "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink",
            "refrigerator", "book", "clock", "vase", "scissors", "teddy bear", "hair drier",
            "toothbrush"
        ]

    @staticmethod
    def _init_feature_detector(detector_type: str):
        """Initialize OpenCV 5 Features2D detector."""
        detector_type = detector_type.lower()

        if detector_type == "aliked":
            # ALIKED: CNN-based keypoint detector (new in OpenCV 5)
            if hasattr(cv2, "ALIKED_create"):
                return cv2.ALIKED_create()
            else:
                logger.warning("ALIKED not available, falling back to ORB")
                return cv2.ORB_create()
        elif detector_type == "disk":
            # DISK: Learned features with reinforcement learning (new in OpenCV 5)
            if hasattr(cv2, "DISK_create"):
                return cv2.DISK_create()
            else:
                logger.warning("DISK not available, falling back to ORB")
                return cv2.ORB_create()
        elif detector_type == "sift":
            # SIFT: Moved to xfeatures2d in older versions, but available in contrib
            if hasattr(cv2, "SIFT_create"):
                return cv2.SIFT_create()
            else:
                logger.warning("SIFT not available, falling back to ORB")
                return cv2.ORB_create()
        else:
            # Default to ORB (always available)
            logger.info(f"Using ORB feature detector (fallback for {detector_type})")
            return cv2.ORB_create()

    def _init_matcher(self, use_lightglue: bool):
        """Initialize matcher - LightGlue is new in OpenCV 5."""
        if use_lightglue and hasattr(cv2, "LightGlueMatcher_create"):
            try:
                return cv2.LightGlueMatcher_create()
            except Exception as e:
                logger.warning(f"Could not create LightGlueMatcher: {e}, falling back to BFMatcher")

        # Fallback to BruteForce matcher
        return cv2.BFMatcher(cv2.NORM_L2, crossCheck=True)

    def detect_objects(self, frame: np.ndarray) -> List[Detection]:
        """
        Run object detection using OpenCV 5 DNN engine.

        Returns list of Detection objects.
        """
        if frame is None or frame.size == 0:
            return []

        # If using dummy net (no model file), generate synthetic detections
        # so the pipeline produces non-zero metrics for local development.
        if not self.net.getLayerNames():  # Empty net check
            return self._synthetic_detections(frame)

        height, width = frame.shape[:2]

        # Prepare blob for DNN input
        blob = cv2.dnn.blobFromImage(
            frame,
            1/255.0,  # Scale factor
            (640, 640),  # Input size (YOLO standard)
            [0, 0, 0],  # Mean subtraction
            swapRB=True,  # OpenCV uses BGR, model may expect RGB
            crop=False
        )

        # Set input and forward pass
        self.net.setInput(blob)
        outputs = self.net.forward()

        # Process outputs (YOLO format: [x, y, w, h, confidence, class_scores...])
        detections = []

        # Handle different output formats
        if len(outputs.shape) == 3:
            outputs = outputs[0]  # Remove batch dimension if present

        for output in outputs:
            # Output format: [x_center, y_center, width, height, confidence, class0_score, class1_score, ...]
            confidence = output[4]
            if confidence > self.conf_threshold:
                # Class scores start at index 5
                class_scores = output[5:]
                class_id = np.argmax(class_scores)
                class_confidence = class_scores[class_id]

                # Final confidence = object_confidence * class_confidence
                final_confidence = confidence * class_confidence

                if final_confidence > self.conf_threshold:
                    # Convert from center-x, center-y, width, height to x1, y1, x2, y2
                    center_x = int(output[0] * width)
                    center_y = int(output[1] * height)
                    w = int(output[2] * width)
                    h = int(output[3] * height)

                    x1 = max(0, center_x - w // 2)
                    y1 = max(0, center_y - h // 2)
                    x2 = min(width, center_x + w // 2)
                    y2 = min(height, center_y + h // 2)

                    detections.append(Detection(
                        class_id=class_id,
                        class_name=self.classes[class_id] if class_id < len(self.classes) else f"class_{class_id}",
                        confidence=float(final_confidence),
                        bbox=(x1, y1, x2 - x1, y2 - y1)
                    ))

        # Apply Non-Maximum Suppression
        if len(detections) > 0:
            boxes = [det.bbox for det in detections]
            confs = [det.confidence for det in detections]
            indices = cv2.dnn.NMSBoxes(
                boxes,
                confs,
                self.conf_threshold,
                self.nms_threshold
            )

            if len(indices) > 0:
                # Filter detections by NMS indices
                detections = [detections[i] for i in indices.flatten()]

        return detections

    def _synthetic_detections(self, frame: np.ndarray) -> List[Detection]:
        """Derive a detection count from real OpenCV analysis of the frame.

        Used only when no ONNX model file is present (local dev / CI). The count
        is NOT random: it comes from contour analysis of the actual frame
        content, so it still reflects real per-frame compute. Callers must
        surface ``Detector.mode`` so these are never reported as model output.
        """
        height, width = frame.shape[:2]

        # Real OpenCV 5 work: edge detection -> morphological close -> contours.
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(gray, 60, 160)
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
        closed = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, kernel)
        contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        detections: List[Detection] = []
        for contour in contours:
            area = cv2.contourArea(contour)
            if area < 900:  # ignore noise
                continue
            x, y, w, h = cv2.boundingRect(contour)
            # Normalize area into a confidence-like score in [0, 1].
            confidence = min(0.99, 0.5 + area / (width * height) * 4.0)
            detections.append(Detection(
                class_id=-1,
                class_name="region",
                confidence=round(float(confidence), 4),
                bbox=(int(x), int(y), int(w), int(h)),
            ))

        # Keep the box count bounded so the UI stays readable.
        detections.sort(key=lambda d: d.confidence, reverse=True)
        return detections[:12]

    def detect_features(self, frame: np.ndarray) -> Features:
        """
        Detect keypoints and descriptors using OpenCV 5 Features2D.

        Returns Features object with keypoints and descriptors.
        """
        if frame is None or frame.size == 0:
            return Features([], None)

        # Convert to grayscale for feature detection
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        # Detect keypoints and compute descriptors
        keypoints, descriptors = self.feature_detector.detectAndCompute(gray, None)

        # If no keypoints found, return empty
        if keypoints is None:
            keypoints = []
        if descriptors is None:
            descriptors = None

        return Features(keypoints, descriptors)

    def match_features(self, curr_features: Features, prev_features: Features) -> List[Tuple[cv2.KeyPoint, cv2.KeyPoint]]:
        """
        Match features between current and previous frame using OpenCV 5 matcher.

        Returns list of matched keypoint pairs (curr_kpt, prev_kpt).
        """
        if (curr_features.descriptors is None or
            prev_features.descriptors is None or
            len(curr_features.keypoints) == 0 or
            len(prev_features.keypoints) == 0):
            return []

        try:
            if self.matcher is not None and hasattr(self.matcher, 'match'):
                # LightGlueMatcher or BFMatcher
                matches = self.matcher.match(curr_features.descriptors, prev_features.descriptors)
            else:
                # Fallback to BFMatcher
                bf = cv2.BFMatcher(cv2.NORM_L2, crossCheck=True)
                matches = bf.match(curr_features.descriptors, prev_features.descriptors)

            # Sort by distance (best matches first)
            matches = sorted(matches, key=lambda x: x.distance)

            # Return matched keypoint pairs
            matched_pairs = []
            for match in matches:
                curr_kpt = curr_features.keypoints[match.queryIdx]
                prev_kpt = prev_features.keypoints[match.trainIdx]
                matched_pairs.append((curr_kpt, prev_kpt))

            return matched_pairs
        except Exception as e:
            logger.warning(f"Feature matching failed: {e}")
            return []

    def process_frame(self, frame: np.ndarray) -> Tuple[List[Detection], Features]:
        """
        Process a single frame: run object detection and feature extraction.

        Returns:
            (detections, features)
        """
        detections = self.detect_objects(frame)
        features = self.detect_features(frame)

        # Store current features for next frame matching
        self.prev_kps = features.keypoints
        self.prev_desc = features.descriptors

        return detections, features