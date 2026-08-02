from sgoda.rlb import CampoEsquema, EsquemaRLB


def crear_esquema() -> EsquemaRLB:
    return EsquemaRLB(
        version="1.0.0",
        campos=[
            CampoEsquema(
                "identificador",
                aliases=("ID", "Código"),
            ),
            CampoEsquema(
                "palabra_puinave",
                aliases=("Puinave", "Palabra Puinave"),
                obligatorio=True,
            ),
            CampoEsquema(
                "traduccion_espanol",
                aliases=("Español", "Castellano"),
            ),
            CampoEsquema(
                "tema_cultural",
                aliases=("Tema cultural",),
            ),
        ],
    )


def test_mapea_aliases_y_preserva_origen() -> None:
    resultado = crear_esquema().mapear_fila(
        {
            "ID": "LEX-0001",
            "Puinave": "AMDA",
            "Español": "ejemplo",
            "Tema cultural": "vida cotidiana",
        },
        archivo="Repositorio Lexico Base.xlsx",
        hoja="Diccionario",
        numero_fila=2,
    )

    assert resultado.errores == []
    assert resultado.registro.identificador == "LEX-0001"
    assert resultado.registro.palabra_puinave == "AMDA"
    assert resultado.registro.tema_cultural == "vida cotidiana"
    assert resultado.registro.origen is not None
    assert resultado.registro.origen.fila == 2


def test_preserva_columnas_nuevas_sin_perder_datos() -> None:
    resultado = crear_esquema().mapear_fila(
        {
            "Puinave": "AMDA",
            "Nuevo campo cultural": "valor no clasificado",
        },
        archivo="RLB.xlsx",
        hoja="Hoja1",
        numero_fila=3,
    )

    assert resultado.errores == []
    assert resultado.columnas_desconocidas == [
        "Nuevo campo cultural"
    ]
    assert resultado.registro.campos_desconocidos[0].valor == (
        "valor no clasificado"
    )


def test_informa_palabra_obligatoria_faltante() -> None:
    resultado = crear_esquema().mapear_fila(
        {"Español": "sin palabra"},
        archivo="RLB.xlsx",
        hoja="Hoja1",
        numero_fila=4,
    )

    assert resultado.errores == [
        "La palabra Puinave es obligatoria."
    ]


def test_rechaza_aliases_duplicados() -> None:
    try:
        EsquemaRLB(
            version="1.0.0",
            campos=[
                CampoEsquema("campo_a", aliases=("Duplicado",)),
                CampoEsquema("campo_b", aliases=("duplicado",)),
            ],
        )
    except ValueError as error:
        assert "Alias duplicado" in str(error)
    else:
        raise AssertionError("Debía rechazarse el alias duplicado")