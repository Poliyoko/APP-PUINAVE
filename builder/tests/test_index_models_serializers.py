from sgoda.repositories import (
    IndexPackage,
    RepositoryIndex,
    dumps_index,
    loads_index,
)


def test_index_roundtrip() -> None:
    index = RepositoryIndex(
        schema_version="1.0",
        repository="official",
        generated_at="2026-07-17T12:00:00+00:00",
        packages=(
            IndexPackage(
                name="demo",
                type="plugin",
                version="1.2.3",
                download_url="https://repo.example.org/demo.sgoda",
                sha256="a" * 64,
            ),
        ),
    )
    restored = loads_index(dumps_index(index))
    assert restored == index
