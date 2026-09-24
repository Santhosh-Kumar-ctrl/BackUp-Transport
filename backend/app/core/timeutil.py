from datetime import date, datetime, time, timezone
from functools import lru_cache
from zoneinfo import ZoneInfo

from app.core.config import settings


@lru_cache
def local_tz() -> ZoneInfo:
    return ZoneInfo(settings.timezone)


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def today_local() -> date:
    return now_utc().astimezone(local_tz()).date()


def local_to_utc(d: date, t: time) -> datetime:
    """Combine a college-local date + wall-clock time into an aware UTC datetime."""
    return datetime.combine(d, t, tzinfo=local_tz()).astimezone(timezone.utc)


def minutes_between(later: datetime, earlier: datetime) -> int:
    """Whole minutes from earlier to later (negative if early), rounded to nearest."""
    return round((later - earlier).total_seconds() / 60)
