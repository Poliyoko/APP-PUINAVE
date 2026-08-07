from dataclasses import asdict
from typing import Dict

from .models import HealthSnapshot


class InstitutionalHealthReporter:
    def to_dict(self, snapshot: HealthSnapshot) -> Dict:
        return {
            "status": snapshot.status.value,
            "healthy_checks": snapshot.healthy_checks,
            "degraded_checks": snapshot.degraded_checks,
            "failed_checks": snapshot.failed_checks,
            "results": [
                {
                    **asdict(result),
                    "severity": result.severity.name,
                }
                for result in snapshot.results
            ],
            "alerts": [
                {
                    **asdict(alert),
                    "severity": alert.severity.name,
                }
                for alert in snapshot.alerts
            ],
            "generated_at_utc": snapshot.generated_at_utc,
        }