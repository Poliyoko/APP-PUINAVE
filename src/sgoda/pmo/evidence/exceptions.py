class EvidenceError(Exception): pass
class EvidenceNotFoundError(EvidenceError): pass
class EvidenceIntegrityError(EvidenceError): pass
class EvidenceValidationError(EvidenceError): pass
class EvidenceConflictError(EvidenceError): pass