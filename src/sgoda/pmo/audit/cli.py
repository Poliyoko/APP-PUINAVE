import argparse
from .service import RepositoryAuditService

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--repository",default=".")
    parser.add_argument("--output",default="artifacts/audit/spb-003.2")
    args=parser.parse_args()
    response=RepositoryAuditService().execute(args.repository,args.output)
    result=response["result"]
    print(f"SGD-401: {response['markdown']}")
    print(f"ACT-003.2: {response['act']}")
    print(f"DICTAMEN: {result.verdict}")
    return 0 if result.verdict=="APPROVED" else 2

if __name__=="__main__":
    raise SystemExit(main())