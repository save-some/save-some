from fastapi import APIRouter, HTTPException

from helpers.db import complete_onboarding
from api.models import OnboardingRequest, User
from api.utils import get_db_handle


router = APIRouter (
    prefix = "/onboarding",
    tags = ["onboarding"]
)


@router.post("/{user_id}", response_model = User, status_code = 201)
def onboard(user_id: str, body: OnboardingRequest):
    """
    Create or update a profile and the user's picked retailers and interests.

    OnboardingRequest has existed in the models since the start with no endpoint
    behind it, so a user with no profiles row had no way to get one and the home
    screen dead-ended on its "finish setting up" state.
    """
    if not body.zipcode.strip():
        raise HTTPException(status_code=422, detail="A zipcode is required")

    with get_db_handle() as conn:
        profile = complete_onboarding(
            conn,
            user_id,
            zipcode = body.zipcode.strip(),
            retailer_ids = [str(r) for r in body.retailers],
            interest_ids = [str(c) for c in body.interests],
        )
    if profile is None:
        raise HTTPException(status_code=500, detail="Could not save the profile")
    return profile
