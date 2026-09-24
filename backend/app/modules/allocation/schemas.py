from datetime import date, datetime

from pydantic import BaseModel, Field

from app.modules.allocation.models import AllocationStatus
from app.modules.master_data.schemas import RouteDetail


class AssignIn(BaseModel):
    student_id: int
    route_id: int
    stop_id: int
    valid_from: date | None = None
    # Admin override: allocate even when the route's seats are all taken.
    force: bool = False


class BulkAssignIn(BaseModel):
    items: list[AssignIn] = Field(min_length=1, max_length=500)


class StudentRef(BaseModel):
    id: int
    full_name: str
    roll_no: str | None


class RouteRef(BaseModel):
    id: int
    code: str
    name: str
    color: str


class StopRef(BaseModel):
    id: int
    name: str


class AllocationOut(BaseModel):
    id: int
    status: AllocationStatus
    valid_from: date
    ended_at: datetime | None
    end_reason: str | None
    route_stop_id: int | None
    student: StudentRef
    route: RouteRef
    stop: StopRef


class AssignResult(BaseModel):
    allocation: AllocationOut
    changed: bool  # False when the student already had exactly this allocation
    warnings: list[str] = []


class BulkItemResult(BaseModel):
    student_id: int
    ok: bool
    result: AssignResult | None = None
    error: str | None = None


class MyAllocation(BaseModel):
    allocation: AllocationOut
    route: RouteDetail
