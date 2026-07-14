class FileGenerator:
    def __init__(self,workspace): self.workspace=workspace
    def create(self,files,*,force=False,dry_run=False):
        out=[]
        for rel,content in files.items():
            p=self.workspace/rel; write=force or not p.exists()
            if write and not dry_run: p.parent.mkdir(parents=True,exist_ok=True); p.write_text(content,encoding="utf-8")
            out.append((p,write))
        return out
