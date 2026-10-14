#!/usr/bin/env python3
"""Convert InsightFace's ArcFace MobileFaceNet (w600k_mbf.onnx) to Core ML.

ONNX → PyTorch (onnx2torch) → traced TorchScript → coremltools ML Program.
The input is declared as a 112×112 RGB *image* with the model's own
normalisation ((px − 127.5) / 127.5) baked in, so Swift only has to hand
Core ML an aligned CVPixelBuffer. Output: a 512-d (un-normalised) embedding.

    .venv/bin/python tools/convert_model.py

Licence: the InsightFace pretrained weights are for NON-COMMERCIAL research
use only. Twinly is a portfolio app and must not ship commercially with them.
"""
import io
import urllib.request
import zipfile
from pathlib import Path

import coremltools as ct
import numpy as np
import onnx
import torch
from onnx2torch import convert

HERE = Path(__file__).resolve().parent
SRC = HERE / "cache" / "buffalo_s" / "w600k_mbf.onnx"
OUT = HERE.parent / "Twinly" / "Resources" / "FaceEmbedder.mlpackage"
PACK = "https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_s.zip"

# The weights aren't in git (their licence doesn't cover redistribution), so
# fetch InsightFace's buffalo_s pack once and keep only the recognition model.
if not SRC.exists():
    print(f"downloading {PACK}")
    with urllib.request.urlopen(PACK) as r, zipfile.ZipFile(io.BytesIO(r.read())) as z:
        name = next(n for n in z.namelist() if n.endswith("w600k_mbf.onnx"))
        SRC.parent.mkdir(parents=True, exist_ok=True)
        SRC.write_bytes(z.read(name))

model = convert(onnx.load(str(SRC))).eval()
example = torch.rand(1, 3, 112, 112) * 2 - 1
traced = torch.jit.trace(model, example)

mlmodel = ct.convert(
    traced,
    inputs=[ct.ImageType(name="face", shape=(1, 3, 112, 112),
                         scale=1 / 127.5, bias=[-1.0, -1.0, -1.0],
                         color_layout=ct.colorlayout.RGB)],
    outputs=[ct.TensorType(name="embedding")],
    convert_to="mlprogram",
    compute_precision=ct.precision.FLOAT16,
    minimum_deployment_target=ct.target.iOS17,
)
mlmodel.short_description = "ArcFace MobileFaceNet (InsightFace w600k_mbf) face embedding"
mlmodel.license = "InsightFace pretrained weights — non-commercial research use only"
mlmodel.author = "InsightFace (deepinsight); converted for Twinly"

# Sanity check: the Core ML output should match PyTorch on the same pixels.
pix = (np.random.rand(112, 112, 3) * 255).astype(np.uint8)
from PIL import Image
ref = model(torch.from_numpy((pix.astype(np.float32) - 127.5) / 127.5).permute(2, 0, 1)[None]).detach().numpy()[0]
got = mlmodel.predict({"face": Image.fromarray(pix)})["embedding"].reshape(-1)
cos = float(np.dot(ref, got) / (np.linalg.norm(ref) * np.linalg.norm(got)))
print(f"PyTorch vs Core ML cosine: {cos:.5f}")
assert cos > 0.99, "conversion mismatch"

OUT.parent.mkdir(parents=True, exist_ok=True)
mlmodel.save(str(OUT))
print(f"saved {OUT}")
