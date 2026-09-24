from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.modules.notifications.models import Severity


class NotificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    type: str
    title: str
    body: str
    severity: Severity
    payload: dict
    read_at: datetime | None
    created_at: datetime


class UnreadCount(BaseModel):
    unread: int


class Message(BaseModel):
    """One message to deliver to a set of users."""

    user_ids: list[int]
    type: str
    title: str
    body: str
    severity: Severity = Severity.INFO
    payload: dict = {}
