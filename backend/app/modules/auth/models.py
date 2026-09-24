from datetime import date

from sqlalchemy import Boolean, Date, ForeignKey, Integer, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.models import Base, TimestampMixin, str_enum
from app.core.roles import Role


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    full_name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str | None] = mapped_column(String(20))
    role: Mapped[Role] = mapped_column(str_enum(Role, "user_role"), index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")

    student: Mapped["StudentProfile | None"] = relationship(
        back_populates="user", uselist=False, lazy="selectin",
        foreign_keys="StudentProfile.user_id",
    )
    driver: Mapped["DriverProfile | None"] = relationship(
        back_populates="user", uselist=False, lazy="selectin"
    )


class StudentProfile(Base):
    __tablename__ = "student_profiles"

    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    roll_no: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    department: Mapped[str | None] = mapped_column(String(80))
    year: Mapped[int | None] = mapped_column(SmallInteger)
    parent_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))

    user: Mapped[User] = relationship(back_populates="student", foreign_keys=[user_id])


class DriverProfile(Base):
    __tablename__ = "driver_profiles"

    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    license_no: Mapped[str] = mapped_column(String(32), unique=True)
    license_expiry: Mapped[date | None] = mapped_column(Date)

    user: Mapped[User] = relationship(back_populates="driver")
