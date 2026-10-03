import torch

print("Loading MiDaS...")

model_type = "MiDaS_small"

midas = torch.hub.load("intel-isl/MiDaS", model_type)

midas.eval()

print("MiDaS loaded successfully!")