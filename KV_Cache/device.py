import torch

def get_accelerator_device() -> str:
    # Prefer cuda
    if torch.cuda.is_available():
        return "cuda"

    elif torch.backend.mps.is_available():
        return "mps"

    else: return "cpu"
