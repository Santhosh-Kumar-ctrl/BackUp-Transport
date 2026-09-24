"""Notifications module: in-app inbox + WebSocket push for operational events."""

from fastapi import FastAPI

from app.core import events
from app.core.db import SessionLocal
from app.modules.notifications import service
from app.modules.notifications.router import router


async def _on_event(ev: events.Event) -> None:
    async with SessionLocal() as session:
        messages = await service.messages_for(session, ev)
        await service.deliver(session, messages)


def register(app: FastAPI) -> None:
    for event_type in service.HANDLED_EVENTS:
        events.subscribe(event_type, _on_event)


__all__ = ["router", "register"]
