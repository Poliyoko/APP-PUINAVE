class ClientSecurityGate:
    REQUIRED_BLOCKING_CONTROLS=frozenset({"CLI-SECRETS","CLI-TLS","CLI-CERT","CLI-STORAGE","CLI-LOGGING","CLI-WEBVIEW","CLI-BACKUP"})
    @classmethod
    def evaluate(cls,controls):
        by={c.control_id:c for c in controls}
        missing=sorted(cls.REQUIRED_BLOCKING_CONTROLS-set(by))
        if missing: return False,["MISSING:"+x for x in missing]
        failed=sorted(x for x in cls.REQUIRED_BLOCKING_CONTROLS if not by[x].passed)
        return not failed,failed
