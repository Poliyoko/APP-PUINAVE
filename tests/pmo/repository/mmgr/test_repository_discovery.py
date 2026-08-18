from pathlib import Path

from sgoda.pmo.repository.mmgr.repository_discovery import (
    RepositoryDeliverableDiscovery,
    extract_codes,
)


def test_extract_standard_code() -> None:
    assert extract_codes("SPT-022") == (("SPT-022", "SPT"),)


def test_extract_subdeliverable() -> None:
    assert extract_codes("SPT-022.1") == (("SPT-022.1", "SPT"),)


def test_extract_letter_suffix() -> None:
    assert extract_codes("SPT-013B") == (("SPT-013B", "SPT"),)


def test_extract_subdeliverable_letter_suffix() -> None:
    assert extract_codes("SPT-019.3E") == (("SPT-019.3E", "SPT"),)


def test_extract_real_code() -> None:
    assert extract_codes("REAL-25") == (("REAL-25", "REAL"),)


def test_path_aliases(tmp_path: Path) -> None:
    discovery = RepositoryDeliverableDiscovery(tmp_path)

    records = discovery.discover_records(
        (
            "tools/sgoda_audio_manager/v0.3.0/README.md",
            "src/SGODA-Visible/app.py",
        )
    )

    codes = {record.code for record in records}

    assert "SGODA-AUDIO" in codes
    assert "SGODA-VISIBLE" in codes


def test_content_discovery(tmp_path: Path) -> None:
    docs = tmp_path / "docs"
    docs.mkdir()

    file_path = docs / "state.md"
    file_path.write_text(
        "SPB-003.2 closed\nSPT-022.1 published\nREAL-25 validated\n",
        encoding="utf-8",
    )

    discovery = RepositoryDeliverableDiscovery(tmp_path)

    items = discovery.discover(("docs/state.md",))

    codes = {item.code for item in items}

    assert codes == {
        "REAL-25",
        "SPB-003.2",
        "SPT-022.1",
    }


def test_deduplicates_same_code_in_same_file(tmp_path: Path) -> None:
    file_path = tmp_path / "history.md"
    file_path.write_text(
        "SPT-024\nSPT-024\nSPT-024\n",
        encoding="utf-8",
    )

    discovery = RepositoryDeliverableDiscovery(tmp_path)

    records = discovery.discover_records(("history.md",))

    assert len(records) == 1
    assert records[0].code == "SPT-024"


def test_preserves_multiple_source_paths(tmp_path: Path) -> None:
    first = tmp_path / "a.md"
    second = tmp_path / "b.md"

    first.write_text("SPT-022\n", encoding="utf-8")
    second.write_text("SPT-022\n", encoding="utf-8")

    discovery = RepositoryDeliverableDiscovery(tmp_path)

    items = discovery.discover(("a.md", "b.md"))

    assert len(items) == 1
    assert items[0].source_path_count == 2
    assert items[0].source_paths == ("a.md", "b.md")


def test_skips_files_over_size_limit(tmp_path: Path) -> None:
    file_path = tmp_path / "large.md"
    file_path.write_text(
        "SPT-999 " + ("x" * 100),
        encoding="utf-8",
    )

    discovery = RepositoryDeliverableDiscovery(
        tmp_path,
        max_text_file_bytes=10,
    )

    items = discovery.discover(("large.md",))

    assert items == ()


def test_path_and_content_sources_are_preserved(tmp_path: Path) -> None:
    folder = tmp_path / "SPT-022"
    folder.mkdir()

    file_path = folder / "SPT-022.md"
    file_path.write_text(
        "SPT-022 closed",
        encoding="utf-8",
    )

    discovery = RepositoryDeliverableDiscovery(tmp_path)

    items = discovery.discover(("SPT-022/SPT-022.md",))

    assert len(items) == 1
    assert items[0].discovery_sources == ("CONTENT", "PATH")