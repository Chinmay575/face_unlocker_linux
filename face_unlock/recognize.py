"""Face embedding extraction using MobileFaceNet ONNX (w600k_mbf from buffalo_s)."""

import numpy as np
import cv2
import onnxruntime as ort


# Standard 5-point alignment target for ArcFace (112x112)
ARCFACE_DST = np.array(
    [
        [38.2946, 51.6963],
        [73.5318, 51.5014],
        [56.0252, 71.7366],
        [41.5493, 92.3655],
        [70.7299, 92.2041],
    ],
    dtype=np.float32,
)


def align_face(img, landmarks):
    """Align face using 5-point landmarks via affine transform to 112x112.

    Args:
        img: BGR image (numpy array)
        landmarks: list of 5 [x, y] landmark points

    Returns:
        Aligned 112x112 face image
    """
    src = np.array(landmarks, dtype=np.float32)
    # Estimate affine transform from detected landmarks to standard positions
    tform = cv2.estimateAffinePartial2D(src, ARCFACE_DST, method=cv2.LMEDS)[0]
    if tform is None:
        # Fallback: simple resize if alignment fails
        x1 = int(min(p[0] for p in landmarks))
        y1 = int(min(p[1] for p in landmarks))
        x2 = int(max(p[0] for p in landmarks))
        y2 = int(max(p[1] for p in landmarks))
        # Expand bbox
        pad = int((x2 - x1) * 0.3)
        x1 = max(0, x1 - pad)
        y1 = max(0, y1 - pad)
        x2 = min(img.shape[1], x2 + pad)
        y2 = min(img.shape[0], y2 + pad * 2)
        face = img[y1:y2, x1:x2]
        return cv2.resize(face, (112, 112))

    aligned = cv2.warpAffine(img, tform, (112, 112), borderValue=0.0)
    return aligned


class FaceRecognizer:
    """MobileFaceNet ONNX face embedding extractor."""

    def __init__(self, model_path):
        self.session = ort.InferenceSession(
            str(model_path), providers=["CPUExecutionProvider"]
        )
        self.input_name = self.session.get_inputs()[0].name

    def get_embedding(self, img, landmarks=None):
        """Extract face embedding from an image.

        Args:
            img: BGR image. If landmarks provided, will align first.
                 Otherwise expects a pre-cropped face image.
            landmarks: optional 5-point landmarks for alignment

        Returns:
            Normalized 512-dim embedding (numpy array)
        """
        if landmarks is not None:
            face = align_face(img, landmarks)
        else:
            face = cv2.resize(img, (112, 112))

        blob = self._preprocess(face)
        output = self.session.run(None, {self.input_name: blob})[0]
        embedding = output.flatten()
        # L2 normalize
        norm = np.linalg.norm(embedding)
        if norm > 0:
            embedding = embedding / norm
        return embedding

    def _preprocess(self, face):
        """Preprocess aligned face for MobileFaceNet input."""
        face = cv2.cvtColor(face, cv2.COLOR_BGR2RGB)
        face = face.astype(np.float32) / 255.0
        face = np.transpose(face, (2, 0, 1))  # HWC -> CHW
        return np.expand_dims(face, axis=0)   # Add batch dim
