import base64
import json
import sys
import wave

import pytest

from sgoda.integration.spt0234.executor import LocalMultimediaExecutor
from sgoda.integration.spt0234.layer2 import Spt0234Layer2Service
from sgoda.integration.spt0234.rmr import RmrRegistry
from sgoda.integration.spt0234.validators import validate_image_file, validate_wav_file


PNG_1X1 = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
)


def write_wav(path):
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(8000)
        handle.writeframes(b"\x00\x00" * 80)


def make_commands():
    image_code = (
        "import base64,pathlib;"
        "pathlib.Path(r'{output}').write_bytes("
        "base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='))"
    )
    wav_code = (
        "import wave,pathlib;"
        "p=pathlib.Path(r'{output}');"
        "p.parent.mkdir(parents=True,exist_ok=True);"
        "w=wave.open(str(p),'wb');"
        "w.setnchannels(1);w.setsampwidth(2);w.setframerate(8000);"
        "w.writeframes(b'\\x00\\x00'*80);w.close()"
    )
    image = f'"{sys.executable}" -c "{image_code}"'
    tts = f'"{sys.executable}" -c "{wav_code}"'
    return image, tts


def plan(resource_type, language=None):
    return {
        "resource_id": f"MM-{resource_type}",
        "lexical_id": "LEX-001",
        "resource_type": resource_type,
        "language": language,
    }


def service(tmp_path):
    image, tts = make_commands()
    return Spt0234Layer2Service(
        executor=LocalMultimediaExecutor(
            image_command=image,
            tts_command=tts,
        ),
        rmr=RmrRegistry(tmp_path / "rmr.json"),
        media_root=tmp_path / "media",
    )


def test_valid_png_is_accepted(tmp_path):
    path = tmp_path / "x.png"
    path.write_bytes(PNG_1X1)
    assert validate_image_file(path)["media_type"] == "image/png"


def test_invalid_image_is_rejected(tmp_path):
    path = tmp_path / "x.png"
    path.write_bytes(b"not-image")
    with pytest.raises(ValueError):
        validate_image_file(path)


def test_valid_wav_is_accepted(tmp_path):
    path = tmp_path / "x.wav"
    write_wav(path)
    assert validate_wav_file(path)["media_type"] == "audio/wav"


def test_invalid_wav_is_rejected(tmp_path):
    path = tmp_path / "x.wav"
    path.write_bytes(b"bad")
    with pytest.raises(ValueError):
        validate_wav_file(path)


def test_image_executes_local_provider(tmp_path):
    result = service(tmp_path).execute_resource(
        plan("image"),
        puinave="AMDA",
        image_prompt="single lexical illustration",
    )
    assert result["status"] == "GENERATED_LOCAL"
    assert result["paid_api_used"] is False


@pytest.mark.parametrize(
    ("resource_type", "locale"),
    [
        ("audio_es", "es-CO"),
        ("audio_en", "en-US"),
        ("audio_it", "it-IT"),
    ],
)
def test_tts_executes_local_provider(tmp_path, resource_type, locale):
    result = service(tmp_path).execute_resource(
        plan(resource_type, locale),
        puinave="AMDA",
        localized_text="texto",
    )
    assert result["status"] == "GENERATED_LOCAL"
    assert result["validation"]["media_type"] == "audio/wav"


def test_puinave_native_audio_is_imported(tmp_path):
    source = tmp_path / "native.wav"
    write_wav(source)
    result = service(tmp_path).execute_resource(
        plan("audio_puinave", "pui"),
        puinave="AMDA",
        native_audio_source=source,
    )
    assert result["status"] == "IMPORTED_NATIVE"
    assert result["provider"] == "NATIVE_HUMAN_RECORDING"


def test_native_audio_missing_source_is_rejected(tmp_path):
    with pytest.raises(ValueError):
        service(tmp_path).execute_resource(
            plan("audio_puinave", "pui"),
            puinave="AMDA",
        )


def test_image_requires_prompt(tmp_path):
    with pytest.raises(ValueError):
        service(tmp_path).execute_resource(
            plan("image"),
            puinave="AMDA",
        )


def test_tts_requires_text(tmp_path):
    with pytest.raises(ValueError):
        service(tmp_path).execute_resource(
            plan("audio_es", "es-CO"),
            puinave="AMDA",
        )


def test_rmr_upsert_and_get(tmp_path):
    registry = RmrRegistry(tmp_path / "rmr.json")
    registry.upsert({"resource_id": "R1", "status": "APPROVED"})
    assert registry.get("R1")["status"] == "APPROVED"


def test_rmr_write_is_valid_json(tmp_path):
    path = tmp_path / "rmr.json"
    registry = RmrRegistry(path)
    registry.upsert({"resource_id": "R1", "status": "APPROVED"})
    assert json.loads(path.read_text(encoding="utf-8"))["resources"]["R1"]["status"] == "APPROVED"


def test_existing_rmr_resource_is_reused(tmp_path):
    svc = service(tmp_path)
    svc.rmr.upsert(
        {
            "resource_id": "MM-image",
            "status": "APPROVED",
            "resource_type": "image",
        }
    )
    result = svc.execute_resource(
        plan("image"),
        puinave="AMDA",
        image_prompt="unused",
    )
    assert result["status"] == "REUSE_EXISTING"
    assert result["reused"] is True


def test_executor_without_image_provider_is_blocked(tmp_path):
    executor = LocalMultimediaExecutor(tts_command="x")
    with pytest.raises(RuntimeError):
        executor.execute_image(
            resource_id="R1",
            lexical_id="L1",
            puinave="A",
            prompt="p",
            output_path=tmp_path / "x.png",
        )


def test_executor_without_tts_provider_is_blocked(tmp_path):
    executor = LocalMultimediaExecutor(image_command="x")
    with pytest.raises(RuntimeError):
        executor.execute_tts(
            resource_id="R1",
            lexical_id="L1",
            resource_type="audio_es",
            language="es-CO",
            text="hola",
            output_path=tmp_path / "x.wav",
        )


def test_unknown_resource_type_is_rejected(tmp_path):
    with pytest.raises(ValueError):
        service(tmp_path).execute_resource(
            plan("video"),
            puinave="AMDA",
        )


def test_execute_full_plan_persists_five_resources(tmp_path):
    svc = service(tmp_path)
    native = tmp_path / "native.wav"
    write_wav(native)

    multimedia_plan = {
        "lexical_id": "LEX-001",
        "puinave": "AMDA",
        "plans": [
            plan("image"),
            plan("audio_puinave", "pui"),
            plan("audio_es", "es-CO"),
            plan("audio_en", "en-US"),
            plan("audio_it", "it-IT"),
        ],
    }
    result = svc.execute_plan(
        multimedia_plan,
        localized_texts={
            "audio_es": "hola",
            "audio_en": "hello",
            "audio_it": "ciao",
        },
        image_prompt="single lexical illustration",
        native_audio_source=native,
    )
    assert result["resources_processed"] == 5
    assert result["rmr_persisted"] is True
    assert len(svc.rmr.load()["resources"]) == 5


def test_full_plan_never_uses_paid_api(tmp_path):
    svc = service(tmp_path)
    native = tmp_path / "native.wav"
    write_wav(native)

    result = svc.execute_plan(
        {
            "lexical_id": "LEX-001",
            "puinave": "AMDA",
            "plans": [
                plan("image"),
                plan("audio_puinave", "pui"),
                plan("audio_es", "es-CO"),
                plan("audio_en", "en-US"),
                plan("audio_it", "it-IT"),
            ],
        },
        localized_texts={
            "audio_es": "hola",
            "audio_en": "hello",
            "audio_it": "ciao",
        },
        image_prompt="single lexical illustration",
        native_audio_source=native,
    )
    assert result["paid_api_used"] is False
    assert result["external_network_required"] is False


def test_layer2_points_to_layer3(tmp_path):
    svc = service(tmp_path)
    native = tmp_path / "native.wav"
    write_wav(native)
    result = svc.execute_plan(
        {
            "lexical_id": "LEX-001",
            "puinave": "AMDA",
            "plans": [
                plan("image"),
                plan("audio_puinave", "pui"),
                plan("audio_es", "es-CO"),
                plan("audio_en", "en-US"),
                plan("audio_it", "it-IT"),
            ],
        },
        localized_texts={
            "audio_es": "hola",
            "audio_en": "hello",
            "audio_it": "ciao",
        },
        image_prompt="single lexical illustration",
        native_audio_source=native,
    )
    assert result["next_component"] == "SPT-023.4-CAPA-3"
