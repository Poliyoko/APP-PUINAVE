from collections.abc import Iterable
from pathlib import Path
class FolderGenerator:
    def __init__(self, workspace: Path)->None:self.workspace=workspace
    def create(self,directories:Iterable[str],*,dry_run:bool=False)->list[tuple[Path,bool]]:
        results=[]
        for rel in directories:
            path=self.workspace/rel; existed=path.exists()
            if not dry_run:path.mkdir(parents=True,exist_ok=True)
            results.append((path,not existed))
        return results
