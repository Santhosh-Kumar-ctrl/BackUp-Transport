from datetime import date, datetime
from enum import Enum

from sqlalchemy import Date, DateTime, ForeignKey, Index, Integer, String, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.models import Base, TimestampMixin, str_enum


class AllocationStatus(str, Enum):
    ACTIVE = "active"
    ENDED = "ended"


class Allocation(Base, TimestampMixin):
    """Which route and stop a student rides. At most one ACTIVE row per student.

    `route_stop_id` is set only while ACTIVE (FK RESTRICT): it stops an admin from
    deleting a stop students still use. When the allocation ends it is cleared,
    and `stop_id` keeps the historical stop.
    """

    __tablename__ = "allocations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    student_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    route_id: Mapped[int] = mapped_column(ForeignKey("routes.id", ondelete="RESTRICT"), index=True)
    route_stop_id: Mapped[int | None] = mapped_column(ForeignKey("route_stops.id", ondelete="RESTRICT"))
    stop_id: Mapped[int] = mapped_column(ForeignKey("stops.id", ondelete="RESTRICT"))
    status: Mapped[AllocationStatus] = mapped_column(
        str_enum(AllocationStatus, "allocation_status"), default=AllocationStatus.ACTIVE
    )
    valid_from: Mapped[date] = mapped_column(Date)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    end_reason: Mapped[str | None] = mapped_column(String(120))
    created_by: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))

    __table_args__ = (
        Index(
            "uq_allocations_one_active_per_student", "student_id",
            unique=True, postgresql_where=text("status = 'active'"),
        ),
    )
