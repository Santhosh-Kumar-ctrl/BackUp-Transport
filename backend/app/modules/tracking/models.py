from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, SmallInteger, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.models import Base


class BusPosition(Base):
    """One GPS fix from the bus (today: the driver's phone), tied to the trip it was sent for."""

    __tablename__ = "bus_positions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    trip_id: Mapped[int | None] = mapped_column(ForeignKey("trips.id", ondelete="CASCADE"))
    bus_id: Mapped[int] = mapped_column(ForeignKey("buses.id", ondelete="CASCADE"))
    latitude: Mapped[float]
    longitude: Mapped[float]
    speed_kmph: Mapped[float | None]
    heading_deg: Mapped[float | None]
    accuracy_m: Mapped[float | None]  # device-reported horizontal accuracy
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)

    # "latest fix of a trip" and "a trip's track in order" are the only lookups.
    __table_args__ = (Index("ix_bus_positions_trip_recorded", "trip_id", "recorded_at"),)


class ApproachAlert(Base):
    """Marks that riders of a stop were told the bus is close, so each stop is announced once per trip."""

    __tablename__ = "approach_alerts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    trip_id: Mapped[int] = mapped_column(ForeignKey("trips.id", ondelete="CASCADE"))
    stop_id: Mapped[int] = mapped_column(ForeignKey("stops.id", ondelete="RESTRICT"))
    sequence: Mapped[int] = mapped_column(SmallInteger)
    distance_m: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (UniqueConstraint("trip_id", "stop_id", name="uq_approach_alerts_trip_stop"),)
