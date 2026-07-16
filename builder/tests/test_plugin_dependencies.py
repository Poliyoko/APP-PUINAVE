from sgoda.extensions import ExtensionRecord, PluginDependencyResolver


def plugin(name, version="1.0.0", dependencies=None, enabled=True):
    return ExtensionRecord(
        type="plugin",
        name=name,
        version=version,
        installed_path=f"/plugins/{name}",
        installed_at="2026-07-16T00:00:00+00:00",
        enabled=enabled,
        dependencies=dependencies or {},
    )


def test_missing_dependency() -> None:
    resolver = PluginDependencyResolver([
        plugin("child", dependencies={"base": ">=1.0.0"}),
    ])
    issues = resolver.issues_for("child")
    assert len(issues) == 1
    assert issues[0].kind == "missing"


def test_satisfied_dependency() -> None:
    resolver = PluginDependencyResolver([
        plugin("base", "1.2.0"),
        plugin("child", dependencies={"base": ">=1.0.0,<2.0.0"}),
    ])
    assert resolver.issues_for("child") == []


def test_cycle_detection() -> None:
    resolver = PluginDependencyResolver([
        plugin("a", dependencies={"b": ">=1.0.0"}),
        plugin("b", dependencies={"a": ">=1.0.0"}),
    ])
    assert resolver.detect_cycles()
