from typing import Dict, List, Set, Tuple

from .models import DependencyComponent
from .registry import ComponentDependencyRegistry
from .versioning import is_compatible


class MissingDependencyError(RuntimeError):
    pass


class DependencyCycleError(RuntimeError):
    pass


class DependencyCompatibilityError(RuntimeError):
    pass


class InstitutionalComponentDependencyManager:
    def __init__(
        self,
        registry: ComponentDependencyRegistry = None,
    ) -> None:
        self.registry = registry or ComponentDependencyRegistry()

    def register(self, component: DependencyComponent) -> None:
        self.registry.register(component)

    def validate_component(self, component_id: str) -> None:
        component = self.registry.get(component_id)

        for requirement in component.dependencies:
            if not self.registry.exists(requirement.component_id):
                raise MissingDependencyError(
                    "missing dependency: {0}".format(
                        requirement.component_id
                    )
                )

            installed = self.registry.get(requirement.component_id)
            if not is_compatible(
                installed.version,
                requirement.minimum_version,
                requirement.maximum_version,
            ):
                raise DependencyCompatibilityError(
                    "incompatible dependency {0}: {1}".format(
                        installed.component_id,
                        installed.version,
                    )
                )

        self._assert_no_cycles()

    def validate_all(self) -> None:
        for component in self.registry.components():
            self.validate_component(component.component_id)

    def installation_order(self) -> Tuple[str, ...]:
        self.validate_all()

        visiting: Set[str] = set()
        visited: Set[str] = set()
        ordered: List[str] = []

        def visit(component_id: str) -> None:
            if component_id in visited:
                return
            if component_id in visiting:
                raise DependencyCycleError(
                    "dependency cycle detected at {0}".format(component_id)
                )

            visiting.add(component_id)
            component = self.registry.get(component_id)

            for requirement in component.dependencies:
                visit(requirement.component_id)

            visiting.remove(component_id)
            visited.add(component_id)
            ordered.append(component_id)

        for component in self.registry.components():
            visit(component.component_id)

        return tuple(ordered)

    def dependents_of(self, component_id: str) -> Tuple[str, ...]:
        dependents = []

        for component in self.registry.components():
            if any(
                dependency.component_id == component_id
                for dependency in component.dependencies
            ):
                dependents.append(component.component_id)

        return tuple(sorted(dependents))

    def _assert_no_cycles(self) -> None:
        visiting: Set[str] = set()
        visited: Set[str] = set()

        def visit(component_id: str) -> None:
            if component_id in visited:
                return
            if component_id in visiting:
                raise DependencyCycleError(
                    "dependency cycle detected at {0}".format(component_id)
                )

            visiting.add(component_id)
            component = self.registry.get(component_id)

            for requirement in component.dependencies:
                if self.registry.exists(requirement.component_id):
                    visit(requirement.component_id)

            visiting.remove(component_id)
            visited.add(component_id)

        for component in self.registry.components():
            visit(component.component_id)