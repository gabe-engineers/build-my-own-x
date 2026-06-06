from dataclasses import dataclass
import time
from typing import Callable

import torch

@dataclass
class GenerationTimings:
    prefill_ms: float = 0.0
    decode_ms: float = 0.0
    prefill_calls: int = 0
    decode_calls: int = 0

    @property
    def total_ms(self) -> float:
        return self.prefill_ms + self.decode_ms

    def as_dict(self) -> dict[str, float | int]:
        average_prefill_ms = self.prefill_ms / self.prefill_calls if self.prefill_calls else 0.0
        average_decode_ms = self.decode_ms / self.decode_calls if self.decode_calls else 0.0
        return {
            "prefill_ms": self.prefill_ms,
            "decode_ms": self.decode_ms,
            "total_ms": self.total_ms,
            "prefill_calls": self.prefill_calls,
            "decode_calls": self.decode_calls,
            "average_prefill_ms": average_prefill_ms,
            "average_decode_ms": average_decode_ms,
        }

def measure_inference_ms(operation: Callable[[], torch.Tensor]) -> tuple[torch.Tensor, float]:
    started_at = time.perf_counter()
    output = operation()
    elapsed_ms = (time.perf_counter() - started_at) * 1000
    return output, elapsed_ms
