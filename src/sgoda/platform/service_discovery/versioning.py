from typing import Tuple


class InvalidServiceVersionError(ValueError):
    pass


def parse_version(value: str) -> Tuple[int, int, int]:
    parts = value.strip().split(".")
    if len(parts) != 3 or not all(part.isdigit() for part in parts):
        raise InvalidServiceVersionError(
            "version must use semantic numeric format X.Y.Z"
        )
    return tuple(int(part) for part in parts)


def is_compatible(
    current: str,
    minimum: str = "0.0.0",
    maximum: str = "",
) -> bool:
    current_value = parse_version(current)
    minimum_value = parse_version(minimum)

    if current_value < minimum_value:
        return False

    if maximum and current_value > parse_version(maximum):
        return False

    return True