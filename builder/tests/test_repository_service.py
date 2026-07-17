import pytest

from sgoda.repositories import RepositoryService, RepositoryServiceError


def test_repository_lifecycle(tmp_path) -> None:
    service = RepositoryService(tmp_path)
    added = service.add("official", "https://repo.example.org", trusted=True)
    assert added.enabled is True
    assert added.trusted is True

    disabled = service.set_enabled("official", False)
    assert disabled.enabled is False
    assert service.list(enabled_only=True) == ()

    enabled = service.set_enabled("official", True)
    assert enabled.enabled is True

    updated = service.add(
        "official", "https://mirror.example.org",
        priority=250, force=True
    )
    assert updated.priority == 250
    assert updated.url == "https://mirror.example.org"

    removed = service.remove("official")
    assert removed.name == "official"
    assert service.list() == ()


def test_duplicate_url_is_rejected(tmp_path) -> None:
    service = RepositoryService(tmp_path)
    service.add("one", "https://repo.example.org")
    with pytest.raises(RepositoryServiceError):
        service.add("two", "https://repo.example.org")
