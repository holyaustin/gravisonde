"""Gravisonde — OpenCV 5 CV pipeline package (exposed via src.__init__)."""

from .pipeline.main import main, run_pipeline
from .pipeline import VideoCapture, Frame, Detector, Detection, Features
from .pipeline.metrics import FrameMetric, BenchmarkRun, MetricsCollector, init_collector, get_collector

__all__ = [
    "main",
    "run_pipeline",
    "init_collector",
    "get_collector",
    "VideoCapture",
    "Frame",
    "Detector",
    "Detection",
    "Features",
    "FrameMetric",
    "BenchmarkRun",
    "MetricsCollector",
]