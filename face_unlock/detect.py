"""Face detection using RetinaFace-MobileNet ONNX (det_500m from buffalo_s)."""

import numpy as np
import cv2
import onnxruntime as ort
from pathlib import Path


class FaceDetector:
    """RetinaFace-MobileNet ONNX face detector."""

    def __init__(self, model_path):
        model_path = str(model_path)
        self.session = ort.InferenceSession(
            model_path, providers=["CPUExecutionProvider"]
        )
        input_cfg = self.session.get_inputs()[0]
        self.input_name = input_cfg.name
        self.input_shape = input_cfg.shape  # e.g. [1, 3, 640, 640]
        self.input_height = self.input_shape[2]
        self.input_width = self.input_shape[3]

    def _preprocess(self, img):
        """Resize and normalize image for RetinaFace input."""
        h, w = img.shape[:2]
        # Compute scale to fit into input size while maintaining aspect ratio
        scale = min(self.input_width / w, self.input_height / h)
        new_w = int(w * scale)
        new_h = int(h * scale)

        resized = cv2.resize(img, (new_w, new_h))

        # Pad to input size
        padded = np.zeros((self.input_height, self.input_width, 3), dtype=np.float32)
        padded[:new_h, :new_w, :] = resized

        # Normalize: standard insightface preprocessing
        blob = cv2.dnn.blobFromImage(
            padded, 1.0 / 128.0, (self.input_width, self.input_height),
            (127.5, 127.5, 127.5), swapRB=True
        )
        return blob, scale

    def detect(self, img, conf_threshold=0.5):
        """Detect faces in an image.

        Args:
            img: BGR image (numpy array)
            conf_threshold: minimum confidence threshold

        Returns:
            list of dicts with keys:
                'bbox': [x1, y1, x2, y2] in original image coordinates
                'confidence': float
                'landmarks': [[x,y], ...] 5 points in original coords
        """
        blob, scale = self._preprocess(img)
        outputs = self.session.run(None, {self.input_name: blob})

        return self._postprocess(outputs, scale, conf_threshold, img.shape[:2])

    def _postprocess(self, outputs, scale, conf_threshold, orig_shape):
        """Decode RetinaFace outputs into face detections.

        The det_500m model outputs are organized by stride (8, 16, 32):
        - scores (3 outputs): confidence for each anchor
        - bboxes (3 outputs): bounding box deltas
        - landmarks (3 outputs): 5-point landmark coordinates
        """
        faces = []
        strides = [8, 16, 32]
        fmc = 3  # feature map count

        # Outputs are in order: scores[0..2], bboxes[0..2], landmarks[0..2]
        for idx, stride in enumerate(strides):
            scores = outputs[idx]
            bbox_deltas = outputs[idx + fmc]
            landmark_deltas = outputs[idx + fmc * 2]

            # Grid dimensions for this stride
            height = self.input_height // stride
            width = self.input_width // stride

            # Generate anchor centers
            anchor_centers = np.stack(
                np.mgrid[:height, :width][::-1], axis=-1
            ).astype(np.float32)
            anchor_centers = (anchor_centers * stride).reshape((-1, 2))

            scores = scores.reshape(-1, 1)
            bbox_deltas = bbox_deltas.reshape(-1, 4)
            landmark_deltas = landmark_deltas.reshape(-1, 10)

            num_anchors = 2
            # Repeat each anchor center for the two anchors at that position
            anchor_centers = np.repeat(anchor_centers, num_anchors, axis=0)

            for i in range(len(scores)):
                conf = float(scores[i, 0])
                if conf < conf_threshold:
                    continue

                cx, cy = anchor_centers[i]
                dx, dy, dw, dh = bbox_deltas[i]

                x1 = (cx - dx * stride) / scale
                y1 = (cy - dy * stride) / scale
                x2 = (cx + dw * stride) / scale
                y2 = (cy + dh * stride) / scale

                # Clip to image bounds
                x1 = max(0, x1)
                y1 = max(0, y1)
                x2 = min(orig_shape[1], x2)
                y2 = min(orig_shape[0], y2)

                # Landmarks
                lm = landmark_deltas[i].reshape(5, 2)
                landmarks = []
                for j in range(5):
                    lx = (lm[j, 0] * stride + cx) / scale
                    ly = (lm[j, 1] * stride + cy) / scale
                    landmarks.append([lx, ly])

                faces.append({
                    "bbox": [float(x1), float(y1), float(x2), float(y2)],
                    "confidence": conf,
                    "landmarks": landmarks,
                })

        # NMS
        if faces:
            faces = self._nms(faces, iou_threshold=0.4)

        return faces

    def _nms(self, faces, iou_threshold=0.4):
        """Non-maximum suppression."""
        if not faces:
            return faces

        faces = sorted(faces, key=lambda x: x["confidence"], reverse=True)
        keep = []

        while faces:
            best = faces.pop(0)
            keep.append(best)
            faces = [
                f for f in faces
                if self._iou(best["bbox"], f["bbox"]) < iou_threshold
            ]

        return keep

    @staticmethod
    def _iou(box1, box2):
        """Compute IoU between two boxes [x1, y1, x2, y2]."""
        x1 = max(box1[0], box2[0])
        y1 = max(box1[1], box2[1])
        x2 = min(box1[2], box2[2])
        y2 = min(box1[3], box2[3])

        inter = max(0, x2 - x1) * max(0, y2 - y1)
        area1 = (box1[2] - box1[0]) * (box1[3] - box1[1])
        area2 = (box2[2] - box2[0]) * (box2[3] - box2[1])
        union = area1 + area2 - inter

        return inter / union if union > 0 else 0
