from sgoda.integration.institutionalmastersync import *

def test_01(): assert len(MASTER_DOCUMENTS)==6
def test_02(): assert validate_master_inventory(reference_master_inventory())["valid"]
def test_03():
    a,m=reference_closure();assert validate_spt025_closure(a,m)["valid"]
def test_04():
    commits={f"SPT-025.{i}":"a"*40 for i in range(1,17)}
    assert len(build_traceability_rows(commits))==16
def test_05():
    commits={f"SPT-025.{i}":"a"*40 for i in range(1,17)}
    assert all(x["preserved"] for x in build_traceability_rows(commits))
def test_06():
    a,m=reference_closure(); commits={f"SPT-025.{i}":"a"*40 for i in range(1,17)}
    state={"local_head":"x","remote_head":"x","staged":0,"deleted_tracked":0}
    assert global_sync_gate(validate_master_inventory(reference_master_inventory()),validate_spt025_closure(a,m),build_traceability_rows(commits),state)["pass"]
def test_07():
    x=reference_master_inventory();x[0]["tracked"]=False
    assert not validate_master_inventory(x)["valid"]
def test_08():
    a,m=reference_closure();a["status"]="OPEN"
    assert not validate_spt025_closure(a,m)["valid"]
def test_09():
    a,m=reference_closure();m["component_coverage"]="15/16"
    assert not validate_spt025_closure(a,m)["valid"]
def test_10():
    a,m=reference_closure();m["real_platform_deployed"]=True
    assert not validate_spt025_closure(a,m)["valid"]
def test_11():
    a,m=reference_closure();m["core_duplicated"]=True
    assert not validate_spt025_closure(a,m)["valid"]
def test_12():
    commits={f"SPT-025.{i}":"a"*40 for i in range(1,16)}
    assert build_traceability_rows(commits)[-1]["commit"]=="UNRESOLVED"
def test_13(): assert len(fingerprint({"a":1}))==64
def test_14(): assert fingerprint({"a":1})==fingerprint({"a":1})
def test_15(): assert MASTER_DOCUMENTS[0].endswith("SGD-000-Estado-Maestro-Institucional-v1.0.0.md")
def test_16(): assert any("SGD-002" in x for x in MASTER_DOCUMENTS)
def test_17(): assert any("00_INDICE_MAESTRO.md" in x for x in MASTER_DOCUMENTS)
def test_18(): assert any("00_REGISTRO_MAESTRO_COMPONENTES.md" in x for x in MASTER_DOCUMENTS)
def test_19(): assert any("SGD-100" in x for x in MASTER_DOCUMENTS)
def test_20():
    a,m=reference_closure(); commits={f"SPT-025.{i}":"a"*40 for i in range(1,17)}
    state={"local_head":"x","remote_head":"y","staged":0,"deleted_tracked":0}
    assert not global_sync_gate(validate_master_inventory(reference_master_inventory()),validate_spt025_closure(a,m),build_traceability_rows(commits),state)["pass"]
def test_21():
    a,m=reference_closure(); commits={f"SPT-025.{i}":"a"*40 for i in range(1,17)}
    state={"local_head":"x","remote_head":"x","staged":1,"deleted_tracked":0}
    assert not global_sync_gate(validate_master_inventory(reference_master_inventory()),validate_spt025_closure(a,m),build_traceability_rows(commits),state)["pass"]
def test_22():
    rows=build_traceability_rows({f"SPT-025.{i}":"a"*40 for i in range(1,17)})
    assert rows[0]["component"]=="SPT-025.1" and rows[-1]["component"]=="SPT-025.16"
def test_23():
    rows=build_traceability_rows({f"SPT-025.{i}":"a"*40 for i in range(1,17)})
    assert all(x["status"]=="INSTITUTIONALLY_CLOSED" for x in rows)
def test_24():
    a,m=reference_closure();assert validate_spt025_closure(a,m)["errors"]==[]
