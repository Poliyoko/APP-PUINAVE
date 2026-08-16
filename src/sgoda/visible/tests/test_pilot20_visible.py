from pathlib import Path
import importlib.util


API_PATH = Path(r"C:/Users/LIDASI~1/AppData/Local/Temp/SGODA-Visible-Pilot20-20260816-174050/src/sgoda/visible/pilot20_api.py")

spec = importlib.util.spec_from_file_location(
    "pilot20_api",
    API_PATH,
)

module = importlib.util.module_from_spec(spec)

spec.loader.exec_module(module)


def test_total_records():

    assert len(
        module.load_records()
    ) == 20


def test_amda():

    row = module.lexical_record(
        "PU-000001"
    )

    assert row["native_word"] == "AMDA"

    assert (
        row["translation_es"]
        == "Hu\u00e9rfana"
    )


def test_abuela():

    row = module.lexical_record(
        "PU-000004"
    )

    assert row["native_word"] == "ANA"

    assert (
        row["translation_es"]
        == "Abuela"
    )


def test_au_identity():

    row16 = module.lexical_record(
        "PU-000016"
    )

    row17 = module.lexical_record(
        "PU-000017"
    )

    assert row16["native_word"] == "AU"
    assert row17["native_word"] == "AU"

    assert (
        row16["translation_es"]
        == "Bachaco"
    )

    assert (
        row17["translation_es"]
        == "Cantar"
    )

    assert (
        row16["native_pronunciation"]
        != row17["native_pronunciation"]
    )


def test_twenty_audio_files():

    for row in module.load_records():

        path = (
            module.AUDIO_ROOT
            / row["audio_file"]
        )

        assert path.is_file()
        assert path.stat().st_size > 0
