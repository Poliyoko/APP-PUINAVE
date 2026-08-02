from __future__ import annotations
import argparse,json,subprocess
from pathlib import Path
from .manager import EvidenceManager
from .models import EvidenceType

def git_value(root:Path,*args:str)->str:
    try:
        return subprocess.run(["git",*args],cwd=root,check=True,capture_output=True,text=True).stdout.strip()
    except (OSError,subprocess.CalledProcessError): return ""

def build_parser()->argparse.ArgumentParser:
    parser=argparse.ArgumentParser(prog="sgoda-sems",description="SGODA Evidence Management System")
    parser.add_argument("--root",default=".")
    sub=parser.add_subparsers(dest="command",required=True)
    register=sub.add_parser("register"); register.add_argument("source")
    register.add_argument("--id",dest="evidence_id"); register.add_argument("--type",choices=[i.value for i in EvidenceType])
    register.add_argument("--deliverable",default=""); register.add_argument("--commit",default=""); register.add_argument("--tag",default="")
    verify=sub.add_parser("verify"); verify.add_argument("evidence_id")
    archive=sub.add_parser("archive"); archive.add_argument("evidence_id"); archive.add_argument("--destination")
    sub.add_parser("status"); sub.add_parser("list"); return parser

def main(argv:list[str]|None=None)->int:
    args=build_parser().parse_args(argv); root=Path(args.root).resolve(); manager=EvidenceManager(root)
    if args.command=="register":
        record=manager.register(Path(args.source),evidence_id=args.evidence_id,
            evidence_type=EvidenceType(args.type) if args.type else None,
            deliverable_id=args.deliverable,commit=args.commit or git_value(root,"rev-parse","HEAD"),tag=args.tag)
        print(json.dumps(record.to_dict(),ensure_ascii=False,indent=2)); return 0
    if args.command=="verify":
        result=manager.verify(args.evidence_id); print(json.dumps(result.to_dict(),ensure_ascii=False,indent=2))
        return 0 if result.valid else 2
    if args.command=="archive":
        record=manager.archive(args.evidence_id,Path(args.destination).resolve() if args.destination else None)
        print(json.dumps(record.to_dict(),ensure_ascii=False,indent=2)); return 0
    if args.command=="status":
        print(json.dumps(manager.status(),ensure_ascii=False,indent=2)); return 0
    if args.command=="list":
        print(json.dumps([r.to_dict() for r in manager.registry.list()],ensure_ascii=False,indent=2)); return 0
    return 2