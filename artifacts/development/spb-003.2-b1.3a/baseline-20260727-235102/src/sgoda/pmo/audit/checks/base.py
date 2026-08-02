from abc import ABC,abstractmethod

class AuditCheck(ABC):
    code="AIR-BASE"
    category="GENERAL"
    name="Control base"

    @abstractmethod
    def run(self,context):
        raise NotImplementedError