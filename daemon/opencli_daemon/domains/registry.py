"""Central domain registry — collects all TaskDomain instances.

Ported from daemon/lib/domains/domain_registry.dart.
"""

from typing import Any

from .base import TaskDomain, DomainDisplayConfig


class DomainRegistry:
    def __init__(self) -> None:
        self._domains: list[TaskDomain] = []
        self._by_id: dict[str, TaskDomain] = {}
        self._by_task_type: dict[str, TaskDomain] = {}

    def register(self, domain: TaskDomain) -> None:
        self._domains.append(domain)
        self._by_id[domain.id] = domain
        for tt in domain.task_types:
            self._by_task_type[tt] = domain

    @property
    def domains(self) -> list[TaskDomain]:
        return list(self._domains)

    @property
    def all_task_types(self) -> list[str]:
        return list(self._by_task_type.keys())

    def get_domain(self, domain_id: str) -> TaskDomain | None:
        return self._by_id.get(domain_id)

    def get_domain_for_task_type(self, task_type: str) -> TaskDomain | None:
        return self._by_task_type.get(task_type)

    def handles_task_type(self, task_type: str) -> bool:
        return task_type in self._by_task_type

    async def execute_task(
        self, task_type: str, task_data: dict[str, Any]
    ) -> dict[str, Any]:
        domain = self._by_task_type.get(task_type)
        if domain is None:
            return {"success": False, "error": f"No domain handles task type: {task_type}"}
        return await domain.execute_task(task_type, task_data)

    async def execute_task_with_progress(
        self, task_type: str, task_data: dict[str, Any], *, on_progress=None
    ) -> dict[str, Any]:
        domain = self._by_task_type.get(task_type)
        if domain is None:
            return {"success": False, "error": f"No domain handles task type: {task_type}"}
        return await domain.execute_task_with_progress(
            task_type, task_data, on_progress=on_progress
        )

    def get_display_config(self, task_type: str) -> DomainDisplayConfig | None:
        domain = self._by_task_type.get(task_type)
        if domain is None:
            return None
        return domain.display_configs.get(task_type)

    async def initialize_all(self) -> None:
        for domain in self._domains:
            try:
                await domain.initialize()
                print(
                    f"[DomainRegistry] Initialized: {domain.id} "
                    f"({len(domain.task_types)} task types)"
                )
            except Exception as e:
                print(f"[DomainRegistry] Warning: failed to init {domain.id}: {e}")
        print(
            f"[DomainRegistry] {len(self._domains)} domains, "
            f"{len(self._by_task_type)} task types"
        )

    def get_stats(self) -> dict:
        return {
            "domainCount": len(self._domains),
            "taskTypeCount": len(self._by_task_type),
            "domains": [
                {
                    "id": d.id,
                    "name": d.name,
                    "taskTypes": d.task_types,
                }
                for d in self._domains
            ],
        }


_global_registry: DomainRegistry | None = None


def get_registry() -> DomainRegistry:
    """Return the global registry (set during daemon startup)."""
    if _global_registry is None:
        raise RuntimeError("Domain registry not initialized")
    return _global_registry


def set_registry(registry: DomainRegistry) -> None:
    """Set the global registry (called during daemon startup)."""
    global _global_registry
    _global_registry = registry


def create_builtin_registry() -> DomainRegistry:
    """Create and populate the registry with all built-in domains."""
    from .timer import TimerDomain
    from .calculator import CalculatorDomain
    from .weather import WeatherDomain
    from .music import MusicDomain
    from .reminders import RemindersDomain
    from .calendar_domain import CalendarDomain
    from .notes import NotesDomain
    from .email_domain import EmailDomain
    from .contacts import ContactsDomain
    from .messages import MessagesDomain
    from .translation import TranslationDomain
    from .files_media import FilesMediaDomain
    from .media_creation.domain import MediaCreationDomain

    registry = DomainRegistry()
    registry.register(TimerDomain())
    registry.register(CalculatorDomain())
    registry.register(MusicDomain())
    registry.register(RemindersDomain())
    registry.register(CalendarDomain())
    registry.register(NotesDomain())
    registry.register(WeatherDomain())
    registry.register(EmailDomain())
    registry.register(ContactsDomain())
    registry.register(MessagesDomain())
    registry.register(TranslationDomain())
    registry.register(FilesMediaDomain())
    registry.register(MediaCreationDomain())
    return registry
