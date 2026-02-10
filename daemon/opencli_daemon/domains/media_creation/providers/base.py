"""Abstract base for cloud video generation providers."""

from abc import ABC, abstractmethod
from typing import Any


class AIVideoProvider(ABC):
    @property
    @abstractmethod
    def name(self) -> str: ...

    @property
    @abstractmethod
    def id(self) -> str: ...

    @abstractmethod
    async def submit(self, prompt: str, *, image_url: str = "", style: str = "", **kwargs: Any) -> str:
        """Submit a generation job, return job_id."""
        ...

    @abstractmethod
    async def poll(self, job_id: str) -> dict[str, Any]:
        """Poll job status. Returns {status, progress, output_url?}."""
        ...

    @abstractmethod
    async def download(self, url: str, dest_path: str) -> str:
        """Download result to dest_path. Returns local path."""
        ...
