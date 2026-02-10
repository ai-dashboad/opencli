"""Abstract base class for all task domains.

Ported from daemon/lib/domains/domain.dart.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any, Callable


@dataclass
class DomainDisplayConfig:
    card_type: str
    title_template: str
    subtitle_template: str | None = None
    icon: str = ""
    color_hex: int = 0xFF000000


ProgressCallback = Callable[[dict[str, Any]], None]


class TaskDomain(ABC):
    """Abstract base class for all task domains."""

    @property
    @abstractmethod
    def id(self) -> str: ...

    @property
    @abstractmethod
    def name(self) -> str: ...

    @property
    @abstractmethod
    def description(self) -> str: ...

    @property
    def icon(self) -> str:
        return ""

    @property
    def color_hex(self) -> int:
        return 0xFF000000

    @property
    @abstractmethod
    def task_types(self) -> list[str]: ...

    @abstractmethod
    async def execute_task(
        self, task_type: str, task_data: dict[str, Any]
    ) -> dict[str, Any]: ...

    @property
    def display_configs(self) -> dict[str, DomainDisplayConfig]:
        return {}

    async def execute_task_with_progress(
        self,
        task_type: str,
        task_data: dict[str, Any],
        *,
        on_progress: ProgressCallback | None = None,
    ) -> dict[str, Any]:
        """Execute with optional progress reporting. Default delegates to execute_task."""
        return await self.execute_task(task_type, task_data)

    async def initialize(self) -> None:
        pass

    async def dispose(self) -> None:
        pass
