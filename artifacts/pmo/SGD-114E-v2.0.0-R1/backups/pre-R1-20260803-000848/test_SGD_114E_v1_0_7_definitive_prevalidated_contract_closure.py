from pathlib import Path
from sgoda.governance.native_ecosystem_validator import evaluate_native_ecosystem

def test_definitive_four_residual_contracts(tmp_path: Path) -> None:
    result = evaluate_native_ecosystem(tmp_path)
    assert result.exit_code == 0
    assert "has_native_components" in result["criteria"]
    assert isinstance(result.native_components, tuple)
    assert result["version"] == "1.0.3"
    assert result.version == "1.0.5"
    assert result.implementation_version == "1.0.7"