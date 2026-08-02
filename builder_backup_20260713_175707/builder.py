

"""
SGODA Project Builder
SPB-001-F001
Versión 0.1.0
"""

from pathlib import Path


VERSION = "0.1.0"


def mostrar_banner():
    print("=" * 60)
    print(" SGODA PROJECT BUILDER")
    print(f" Versión {VERSION}")
    print("=" * 60)


def obtener_raiz():
    return Path(__file__).resolve().parent.parent


def main():
    mostrar_banner()

    raiz = obtener_raiz()

    print(f"\nProyecto : {raiz.name}")
    print(f"Ruta      : {raiz}")

    print("\nEstado")
    print("------")
    print("✔ Builder iniciado correctamente")
    print("✔ Proyecto localizado")
    print("✔ Python funcionando")


if __name__ == "__main__":
    main()





    





