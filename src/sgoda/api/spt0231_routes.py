import os
from pathlib import Path
from fastapi import APIRouter,HTTPException
from pydantic import BaseModel
from sgoda.integration.spt0231.service import Spt0231Service
router=APIRouter(prefix="/api/spt0231",tags=["SPT-023.1"])
class DetectionRequest(BaseModel): source_path:str
@router.get("/health")
def health(): return {"component":"SPT-023.1","status":"OPERATIONAL","capability":"INTELLIGENT_PUINAVE_WORD_DETECTION"}
@router.post("/detect")
def detect(req:DetectionRequest):
    root=Path(os.environ.get("SGODA_PROJECT_ROOT",Path.cwd())).resolve(); source=Path(req.source_path); source=source if source.is_absolute() else (root/source).resolve()
    try:return Spt0231Service(root).detect_file(source)
    except Exception as e: raise HTTPException(status_code=400,detail=str(e)) from e