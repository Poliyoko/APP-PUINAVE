from __future__ import annotations
import json, zipfile
from datetime import datetime, timezone
from pathlib import Path
from .hasher import iter_files, sha256_file
from .manifest import build_manifest

def create_archive(source:Path,destination:Path,*,metadata:dict|None=None)->tuple[Path,str]:
    source=source.resolve(); destination=destination.resolve()
    destination.parent.mkdir(parents=True,exist_ok=True)
    manifest=build_manifest(source); base=source if source.is_dir() else source.parent
    package={"schema":"sgoda.sems.archive/v1",
             "created_at_utc":datetime.now(timezone.utc).isoformat(),
             "source":source.as_posix(),"metadata":metadata or {}}
    with zipfile.ZipFile(destination,"w",compression=zipfile.ZIP_DEFLATED) as z:
        for file_path in iter_files(source):
            z.write(file_path,arcname=f"payload/{file_path.relative_to(base).as_posix()}")
        z.writestr("manifest.json",json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
        z.writestr("archive-metadata.json",json.dumps(package,ensure_ascii=False,indent=2)+"\n")
    return destination,sha256_file(destination)