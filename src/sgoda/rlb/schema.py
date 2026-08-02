"""Esquema versionado y mapeo de columnas del RLB."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Iterable

from .models import CampoDesconocido, OrigenRLB, RegistroLexico


def _normalizar_encabezado(valor: str) -> str:
    return " ".join(valor.strip().lower().replace("_", " ").split())


@dataclass(frozen=True, slots=True)
class CampoEsquema:
    nombre_canonico: str
    aliases: tuple[str, ...] = ()
    obligatorio: bool = False

    def nombres_normalizados(self) -> set[str]:
        return {
            _normalizar_encabezado(nombre)
            for nombre in (self.nombre_canonico, *self.aliases)
        }


@dataclass(slots=True)
class ResultadoMapeo:
    registro: RegistroLexico
    columnas_reconocidas: dict[str, str] = field(default_factory=dict)
    columnas_desconocidas: list[str] = field(default_factory=list)
    errores: list[str] = field(default_factory=list)


class EsquemaRLB:
    """Contrato extensible para mapear versiones del Excel al modelo canónico."""

    def __init__(
        self,
        version: str,
        campos: Iterable[CampoEsquema],
    ) -> None:
        self.version = version
        self.campos = tuple(campos)
        self._indice = self._construir_indice()

    def _construir_indice(self) -> dict[str, str]:
        indice: dict[str, str] = {}

        for campo in self.campos:
            for nombre in campo.nombres_normalizados():
                if nombre in indice:
                    raise ValueError(
                        f"Alias duplicado en el esquema: {nombre!r}"
                    )
                indice[nombre] = campo.nombre_canonico

        return indice

    def mapear_fila(
        self,
        fila: dict[str, Any],
        *,
        archivo: str,
        hoja: str,
        numero_fila: int,
    ) -> ResultadoMapeo:
        valores: dict[str, Any] = {}
        reconocidas: dict[str, str] = {}
        desconocidos: list[CampoDesconocido] = []

        for columna_original, valor in fila.items():
            encabezado = _normalizar_encabezado(str(columna_original))
            nombre_canonico = self._indice.get(encabezado)

            if nombre_canonico is None:
                desconocidos.append(
                    CampoDesconocido(
                        columna_original=str(columna_original),
                        valor=valor,
                    )
                )
                continue

            valores[nombre_canonico] = valor
            reconocidas[str(columna_original)] = nombre_canonico

        palabra = str(valores.get("palabra_puinave") or "").strip()

        registro = RegistroLexico(
            identificador=_texto_opcional(valores.get("identificador")),
            palabra_puinave=palabra,
            traduccion_espanol=_texto_opcional(
                valores.get("traduccion_espanol")
            ),
            traduccion_ingles=_texto_opcional(
                valores.get("traduccion_ingles")
            ),
            categoria_gramatical=_texto_opcional(
                valores.get("categoria_gramatical")
            ),
            categoria_tematica=_texto_opcional(
                valores.get("categoria_tematica")
            ),
            tema_cultural=_texto_opcional(valores.get("tema_cultural")),
            descripcion_cultural=_texto_opcional(
                valores.get("descripcion_cultural")
            ),
            contexto_uso=_texto_opcional(valores.get("contexto_uso")),
            comunidad=_texto_opcional(valores.get("comunidad")),
            territorio=_texto_opcional(valores.get("territorio")),
            imagen=_texto_opcional(valores.get("imagen")),
            audio_puinave=_texto_opcional(valores.get("audio_puinave")),
            audio_espanol=_texto_opcional(valores.get("audio_espanol")),
            audio_ingles=_texto_opcional(valores.get("audio_ingles")),
            video=_texto_opcional(valores.get("video")),
            nivel_acceso=(
                _texto_opcional(valores.get("nivel_acceso"))
                or "pendiente_clasificacion"
            ),
            autorizacion_publicacion=_booleano(
                valores.get("autorizacion_publicacion")
            ),
            estado_validacion=(
                _texto_opcional(valores.get("estado_validacion"))
                or "pendiente"
            ),
            origen=OrigenRLB(
                archivo=archivo,
                hoja=hoja,
                fila=numero_fila,
                version_esquema=self.version,
            ),
            campos_desconocidos=desconocidos,
        )

        return ResultadoMapeo(
            registro=registro,
            columnas_reconocidas=reconocidas,
            columnas_desconocidas=[
                campo.columna_original for campo in desconocidos
            ],
            errores=registro.validar_minimo(),
        )


def _texto_opcional(valor: Any) -> str | None:
    if valor is None:
        return None

    texto = str(valor).strip()
    return texto or None


def _booleano(valor: Any) -> bool:
    if isinstance(valor, bool):
        return valor

    if valor is None:
        return False

    return str(valor).strip().lower() in {
        "1",
        "sí",
        "si",
        "true",
        "verdadero",
        "autorizado",
    }