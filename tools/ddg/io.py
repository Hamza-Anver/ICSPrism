from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def load_json(path: Path | str) -> Any:
    with Path(path).open(encoding="utf-8") as f:
        return json.load(f)


def load_ddg(path: Path | str) -> dict:
    data = load_json(path)
    if not isinstance(data, dict):
        raise ValueError(f"{path}: DDG JSON must be an object with nodes and edges")
    return data


def load_layout(path: Path | str) -> list:
    data = load_json(path)
    return data if isinstance(data, list) else [data]


def load_weights(path: Path | str) -> dict:
    data = load_json(path)
    if not isinstance(data, dict):
        raise ValueError(f"{path}: weights JSON must be an object")
    return data
