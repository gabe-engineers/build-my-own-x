import torch


def resolve_target_device(target_device: str) -> str:
    normalized_device = target_device.strip().lower()

    if normalized_device == "auto":
        if torch.cuda.is_available() and cuda_device_is_supported("cuda"):
            return "cuda"
        if torch.backends.mps.is_available():
            return "mps"
        return "cpu"

    if normalized_device == "cpu":
        return "cpu"

    if normalized_device == "mps":
        if not torch.backends.mps.is_available():
            raise ValueError("target_device `mps` was requested, but MPS is not available.")
        return "mps"

    if normalized_device == "cuda" or normalized_device.startswith("cuda:"):
        if not torch.cuda.is_available():
            raise ValueError(f"target_device `{normalized_device}` was requested, but CUDA is not available.")
        if not cuda_device_is_supported(normalized_device):
            capability = torch.cuda.get_device_capability(normalized_device)
            arch_list = ", ".join(torch.cuda.get_arch_list()) or "unknown"
            raise ValueError(
                f"target_device `{normalized_device}` was requested, but this PyTorch build does not support "
                f"CUDA capability sm_{capability[0]}{capability[1]}. Supported architectures: {arch_list}."
            )
        return normalized_device

    raise ValueError(f"Unsupported target_device `{target_device}`. Use auto, cpu, mps, cuda, or cuda:N.")


def cuda_device_is_supported(device: str) -> bool:
    supported_arches = torch.cuda.get_arch_list()
    if not supported_arches:
        return True

    capability = torch.cuda.get_device_capability(device)
    for arch in supported_arches:
        if "_" not in arch:
            continue
        _, version = arch.split("_", maxsplit=1)
        if len(version) < 2 or not version.isdigit():
            continue
        major = int(version[:-1])
        minor = int(version[-1])
        if capability[0] == major and capability[1] >= minor:
            return True

    return False


def synchronize_device(device: str):
    if device.startswith("cuda"):
        torch.cuda.synchronize(device=device)
        return

    if device == "mps" and hasattr(torch, "mps") and torch.backends.mps.is_available():
        torch.mps.synchronize()
