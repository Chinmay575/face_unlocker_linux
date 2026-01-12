import cv2 
import numpy as np
import onnxruntime as ort

class FaceEmbedder:
    def __init__(self, model_path:str):
        self.session = ort.InferenceSession(model_path, provider_options=["CPUExecutionProvider"])
        self.input_name = self.session.get_inputs()[0].name

    def preprocess(self, face) :
        face = cv2.resize(face, (112, 112))
        face = cv2.cvtColor(face, cv2.COLOR_BGR2RGB)
        face = face.astype(np.float32)/255.0
        face = np.transpose(face, (2,0, 1))
        return np.expand_dims(face, axis=0)
    
    def embed(self, face):
        imp = self.preprocess(face)
        emb = self.session.run(None, {self.input_name : imp})[0]
        emb = emb/np.linalg.norm(emb)
        return emb.flatten()
    
