from __future__ import annotations
import hashlib
from pathlib import Path
from typing import Iterable

def sha256_file(path: Path, chunk_size: int=1024*1024) -> str:
    digest=hashlib.sha256()
    with path.open("rb") as stream:
        while True:
            chunk=stream.read(chunk_size)
            if not chunk: break
            digest.update(chunk)
    return digest.hexdigest()

def iter_files(path: Path) -> Iterable[Path]:
    if path.is_file():
        yield path; return
    for candidate in sorted(path.rglob("*")):
        if candidate.is_file(): yield candidate

def sha256_directory(path: Path) -> str:
    digest=hashlib.sha256(); base=path.resolve()
    for file_path in iter_files(base):
        relative=file_path.resolve().relative_to(base).as_posix()
        digest.update(relative.encode("utf-8")); digest.update(b"\0")
        digest.update(sha256_file(file_path).encode("ascii")); digest.update(b"\0")
    return digest.hexdigest()

def calculate_sha256(path: Path) -> str:
    if path.is_file(): return sha256_file(path)
    if path.is_dir(): return sha256_directory(path)
    raise FileNotFoundError(path)

def calculate_size(path: Path) -> int:
    if path.is_file(): return path.stat().st_size
    return sum(p.stat().st_size for p in iter_files(path))