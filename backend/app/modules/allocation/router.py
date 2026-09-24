from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.deps import Principal, require_roles
from app.core.errors import NotFound
from app.core.roles import Role
from app.modules.allocation import service
from app.modules.allocation.models import AllocationStatus
from app.modules.allocation.schemas import (
    AllocationOut,
    AssignIn,
    AssignResult,
    BulkAssignIn,
    BulkItemResult,
    MyAllocation,
)
from app.modules.master_data import service as md_service
from app.modules.master_data.schemas import RouteDetail

router = APIRouter(tags=["allocation"])
admin_only = require_roles(Role.ADMIN)


@router.get("/allocations", response_model=list[AllocationOut])
async def list_allocations(route_id: int | None = None, stop_id: int | None = None,
                           student_id: int | None = None, include_ended: bool = False,
                           _: Principal = Depends(admin_only), session: AsyncSession = Depends(get_session)):
    rows = await service.list_allocations(session, route_id=route_id, stop_id=stop_id, student_id=student_id,
                                          status=None if include_ended else AllocationStatus.ACTIVE)
    return await service.to_out(session, rows)


@router.post("/allocations", response_model=AssignResult)
async def assign(body: AssignIn, p: Principal = Depends(admin_only),
                 session: AsyncSession = Depends(get_session)):
    res = await service.assign(session, body, actor_id=p.id)
    await session.commit()
    return res


@router.post("/allocations/bulk", response_model=list[BulkItemResult])
async def bulk_assign(body: BulkAssignIn, p: Principal = Depends(admin_only),
                      session: AsyncSession = Depends(get_session)):
    res = await service.bulk_assign(session, body.items, actor_id=p.id)
    await session.commit()
    return res


@router.delete("/allocations/students/{student_id}", status_code=204)
async def unassign(student_id: int, p: Principal = Depends(admin_only),
                   session: AsyncSession = Depends(get_session)):
    await service.unassign(session, student_id, actor_id=p.id)
    await session.commit()
    return Response(status_code=204)


@router.get("/allocations/me", response_model=MyAllocation)
async def my_allocation(p: Principal = Depends(require_roles(Role.STUDENT)),
                        session: AsyncSession = Depends(get_session)):
    a = await service.get_active(session, p.id)
    if a is None:
        raise NotFound("You are not allocated to a route yet", code="not_allocated")
    route = await md_service.get_route(session, a.route_id)
    return MyAllocation(allocation=(await service.to_out(session, [a]))[0],
                        route=RouteDetail.model_validate(route))
