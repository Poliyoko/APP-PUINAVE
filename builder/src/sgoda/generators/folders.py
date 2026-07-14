class FolderGenerator:
    def __init__(self,workspace): self.workspace=workspace
    def create(self,dirs,*,dry_run=False):
        out=[]
        for rel in dirs:
            p=self.workspace/rel; created=not p.exists()
            if not dry_run: p.mkdir(parents=True,exist_ok=True)
            out.append((p,created))
        return out
