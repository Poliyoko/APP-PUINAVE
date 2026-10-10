"""Opt-in FastAPI adapter for existing C3; authentication stays with the host."""

from threading import Lock

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field, StrictBool

from .layer3 import Spt0233Layer3GovernanceService
from .proposal import build_category_proposal


class ReviewBody(BaseModel):
    model_config = ConfigDict(extra="forbid")
    proposed_name: str = Field(min_length=1, max_length=200)
    approve: StrictBool
    reason: str = Field(min_length=1, max_length=1000)
    category_id: str | None = Field(default=None, max_length=200)
    parent_id: str | None = Field(default=None, max_length=200)


def authenticated_reviewer(request: Request) -> str:
    """Only trust AuthenticationMiddleware's verified principal and scopes.

    The deployment backend must verify credentials and set a stable, issuer-
    qualified identity plus authenticated/human/category:review scopes.
    No request header or body is interpreted as a principal here.
    """
    user = request.scope.get("user")
    auth = request.scope.get("auth")
    scopes = set(getattr(auth, "scopes", ()))
    if user is None or not user.is_authenticated or "authenticated" not in scopes:
        raise HTTPException(status_code=401, detail="Authenticated reviewer required")
    if not {"human", "category:review"}.issubset(scopes):
        raise HTTPException(status_code=403, detail="Human category reviewer permission required")
    identity = str(getattr(user, "identity", "") or "").strip()
    if not identity:
        raise HTTPException(status_code=401, detail="Stable reviewer identity required")
    return identity


def create_review_router(service: Spt0233Layer3GovernanceService) -> APIRouter:
    """Mount explicitly in a host with verified AuthenticationMiddleware.

    One worker per registry/ledger pair is required: the existing file store
    has no distributed transaction lock. No production mount is implicit.
    """
    router = APIRouter(prefix="/categories", tags=["categories"])
    lock = Lock()

    @router.post("/proposals/review")
    def review(body: ReviewBody, reviewer: str = Depends(authenticated_reviewer)) -> dict:
        proposal = build_category_proposal([body.proposed_name])
        if proposal is None:
            raise HTTPException(status_code=422, detail="Nonempty proposal required")
        try:
            with lock:
                return service.review_proposal(
                    proposal, approve=body.approve, reviewer=reviewer,
                    reason=body.reason, category_id=body.category_id,
                    parent_id=body.parent_id,
                )
        except ValueError:
            raise HTTPException(status_code=422, detail="Invalid category review") from None

    return router
