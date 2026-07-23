"""Excepciones específicas del dominio DMP."""


class DmpDomainError(Exception):
    """Excepción base para errores de negocio del dominio DMP."""


class InvalidStateTransition(DmpDomainError):
    """Indica que una transición de estado no está permitida."""
