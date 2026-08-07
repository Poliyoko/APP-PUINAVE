from typing import List, Set, Tuple

from .registry import RuntimeUnitRegistry


class RuntimeDependencyError(RuntimeError):
    pass


class RuntimeDependencyCycleError(RuntimeDependencyError):
    pass


class RuntimePlanner:
    def __init__(self, registry: RuntimeUnitRegistry) -> None:
        self.registry = registry

    def startup_order(self) -> Tuple[str, ...]:
        visiting: Set[str] = set()
        visited: Set[str] = set()
        ordered: List[str] = []

        def visit(unit_id: str) -> None:
            if unit_id in visited:
                return

            if unit_id in visiting:
                raise RuntimeDependencyCycleError(
                    "runtime dependency cycle detected at {0}".format(
                        unit_id
                    )
                )

            visiting.add(unit_id)
            record = self.registry.get(unit_id)

            for dependency in record.definition.dependencies:
                if not self.registry.exists(dependency):
                    raise RuntimeDependencyError(
                        "missing runtime dependency: {0}".format(
                            dependency
                        )
                    )
                visit(dependency)

            visiting.remove(unit_id)
            visited.add(unit_id)
            ordered.append(unit_id)

        for record in self.registry.records():
            visit(record.definition.unit_id)

        return tuple(ordered)

    def shutdown_order(self) -> Tuple[str, ...]:
        return tuple(reversed(self.startup_order()))