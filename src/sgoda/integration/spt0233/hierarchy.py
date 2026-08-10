from __future__ import annotations

from dataclasses import dataclass

from .catalog import CategoryCatalog, CategoryDefinition


@dataclass(frozen=True)
class CategoryNode:
    category_id: str
    name: str
    parent_id: str | None


class CategoryHierarchy:
    """JerarquÃ­a de solo lectura construida desde CategoryCatalog.

    La relaciÃ³n padre se obtiene de metadata["parent_id"]. La capa valida
    referencias y ciclos, pero nunca modifica el catÃ¡logo institucional.
    """

    def __init__(self, catalog: CategoryCatalog) -> None:
        self._by_id: dict[str, CategoryDefinition] = {
            item.category_id: item for item in catalog.categories
        }
        self._parent: dict[str, str | None] = {}

        for item in catalog.categories:
            metadata = item.metadata or {}
            raw_parent = metadata.get("parent_id")
            parent_id = str(raw_parent).strip() if raw_parent else None

            if parent_id and parent_id not in self._by_id:
                raise ValueError(
                    f"Unknown parent category {parent_id!r} for {item.category_id!r}"
                )
            if parent_id == item.category_id:
                raise ValueError(f"Category {item.category_id!r} cannot parent itself")

            self._parent[item.category_id] = parent_id

        for category_id in self._by_id:
            self._validate_no_cycle(category_id)

    def _validate_no_cycle(self, category_id: str) -> None:
        seen: set[str] = set()
        current: str | None = category_id

        while current is not None:
            if current in seen:
                raise ValueError(f"Category hierarchy cycle detected at {current!r}")
            seen.add(current)
            current = self._parent.get(current)

    def lineage(self, category_id: str) -> tuple[CategoryNode, ...]:
        if category_id not in self._by_id:
            raise KeyError(category_id)

        chain: list[CategoryNode] = []
        current: str | None = category_id

        while current is not None:
            definition = self._by_id[current]
            parent_id = self._parent[current]
            chain.append(
                CategoryNode(
                    category_id=definition.category_id,
                    name=definition.name,
                    parent_id=parent_id,
                )
            )
            current = parent_id

        chain.reverse()
        return tuple(chain)

    def principal(self, category_id: str) -> CategoryNode:
        return self.lineage(category_id)[0]

    def subcategories(self, category_id: str) -> tuple[CategoryNode, ...]:
        lineage = self.lineage(category_id)
        return lineage[1:]

    def children(self, category_id: str) -> tuple[CategoryNode, ...]:
        if category_id not in self._by_id:
            raise KeyError(category_id)

        nodes = [
            CategoryNode(
                category_id=item.category_id,
                name=item.name,
                parent_id=self._parent[item.category_id],
            )
            for item in self._by_id.values()
            if self._parent[item.category_id] == category_id
        ]
        return tuple(sorted(nodes, key=lambda item: item.category_id))
