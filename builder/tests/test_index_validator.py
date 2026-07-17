import pytest

from sgoda.repositories import (
    IndexPackage,
    IndexValidationError,
    RepositoryIndex,
    validate_index,
)


def make_index(**changes):
    package = IndexPackage(
        name="demo",
        type="plugin",
        version="1.0.0",
        download_url="https://repo.example.org/demo.sgoda",
        sha256="a" * 64,
    )
    values = {
        "schema_version": "1.0",
        "repository": "official",
        "generated_at": "2026-07-17T12:00:00+00:00",
        "packages": (package,),
    }
    values.update(changes)
    return RepositoryIndex(**values)


def test_valid_index() -> None:
    validate_index(make_index(), expected_repository="official")


@pytest.mark.parametrize(
    "index",
    [
        make_index(schema_version="2.0"),
        make_index(repository="other"),
        make_index(generated_at="not-a-date"),
        make_index(packages=(
            IndexPackage("demo", "plugin", "bad", "https://repo.example.org/a", "a" * 64),
        )),
    ],
)
def test_invalid_indices(index) -> None:
    with pytest.raises(IndexValidationError):
        validate_index(index, expected_repository="official")
