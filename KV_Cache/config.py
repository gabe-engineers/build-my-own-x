from pathlib import Path
from typing import Any

from pydantic import BaseModel, ConfigDict, ValidationError, field_validator
import yaml

CONFIG_PATH_ENV_VAR = "KV_CACHE_CONFIG"


class RuntimeConfig(BaseModel):
    model_config = ConfigDict(extra="forbid")

    kv_cache: bool = True
    target_device: str = "auto"

    @field_validator("target_device")
    @classmethod
    def normalize_target_device(cls, value: str) -> str:
        normalized = value.strip().lower()
        if not normalized:
            raise ValueError("target_device cannot be empty.")
        return normalized


def _normalize_config_data(raw_config: dict[str, Any]) -> dict[str, Any]:
    normalized = dict(raw_config)
    normalized.pop("model_name", None)
    model_config = normalized.pop("model", None)
    if model_config is not None:
        if not isinstance(model_config, dict):
            raise ValueError("`model` must be a mapping when provided.")
        model_config = dict(model_config)
        model_config.pop("name", None)
        model_config.pop("model_name", None)
        normalized = {**model_config, **normalized}

    kv_cache = normalized.get("kv_cache")
    if isinstance(kv_cache, dict):
        if "enabled" not in kv_cache:
            raise ValueError("`kv_cache.enabled` is required when `kv_cache` is a mapping.")
        normalized["kv_cache"] = kv_cache["enabled"]

    return normalized


def load_runtime_config(config_path: str | Path | None = None) -> RuntimeConfig:
    if config_path is None:
        return RuntimeConfig()

    path = Path(config_path).expanduser()
    if not path.is_file():
        raise ValueError(f"Config file not found: {path}")

    with path.open("r", encoding="utf-8") as config_file:
        raw_config = yaml.safe_load(config_file)

    if raw_config is None:
        raw_config = {}

    if not isinstance(raw_config, dict):
        raise ValueError("The YAML config must contain a top-level mapping.")

    normalized_config = _normalize_config_data(raw_config)

    try:
        return RuntimeConfig.model_validate(normalized_config)
    except ValidationError as exc:
        raise ValueError(f"Invalid runtime config in {path}: {exc}") from exc
