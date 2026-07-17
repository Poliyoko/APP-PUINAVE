import pytest

from sgoda.repositories import (
    RepositoryValidationError,
    normalize_name,
    normalize_url,
    validate_priority,
)


def test_repository_validation() -> None:
    assert normalize_name(" Official ") == "official"
    assert normalize_url("https://repo.example.org/") == "https://repo.example.org"
    assert validate_priority(100) == 100


@pytest.mark.parametrize("url", ["ftp://example.org", "repo.example.org", "https://user:pass@example.org"])
def test_invalid_repository_urls(url: str) -> None:
    with pytest.raises(RepositoryValidationError):
        normalize_url(url)
