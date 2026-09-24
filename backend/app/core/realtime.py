"""WebSocket hub: pushes live updates to connected clients.

Channels a socket receives from:
  * its own user   -> hub.send_to_user(user_id, msg)
  * its role       -> hub.send_to_role(Role.ADMIN, msg)
  * topics it asked for, e.g. "route:3" or "trip:12" -> hub.send_to_topic("trip:12", msg)

Client protocol (JSON text frames):
  -> {"action": "subscribe", "topic": "route:3"}
  -> {"action": "unsubscribe", "topic": "route:3"}
  -> {"action": "ping"}                      <- {"type": "pong"}
  <- {"type": "<message type>", "data": {...}}

In-memory and single-process. To run several API workers, back this with Redis pub/sub.
"""

import asyncio
import logging
from collections import defaultdict
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.core.deps import Principal, principal_from_token
from app.core.errors import DomainError
from app.core.events import jsonable
from app.core.roles import Role

log = logging.getLogger("transit.realtime")


class Hub:
    def __init__(self) -> None:
        self._by_user: dict[int, set[WebSocket]] = defaultdict(set)
        self._by_role: dict[Role, set[WebSocket]] = defaultdict(set)
        self._by_topic: dict[str, set[WebSocket]] = defaultdict(set)
        self._topics_of: dict[WebSocket, set[str]] = defaultdict(set)
        self._principal: dict[WebSocket, Principal] = {}

    def add(self, ws: WebSocket, p: Principal) -> None:
        self._principal[ws] = p
        self._by_user[p.id].add(ws)
        self._by_role[p.role].add(ws)

    def remove(self, ws: WebSocket) -> None:
        p = self._principal.pop(ws, None)
        if p:
            self._by_user[p.id].discard(ws)
            self._by_role[p.role].discard(ws)
        for topic in self._topics_of.pop(ws, set()):
            self._by_topic[topic].discard(ws)

    def subscribe(self, ws: WebSocket, topic: str) -> None:
        self._by_topic[topic].add(ws)
        self._topics_of[ws].add(topic)

    def unsubscribe(self, ws: WebSocket, topic: str) -> None:
        self._by_topic[topic].discard(ws)
        self._topics_of[ws].discard(topic)

    async def _send(self, sockets: set[WebSocket], msg_type: str, data: Any) -> None:
        if not sockets:
            return
        frame = {"type": msg_type, "data": jsonable(data)}
        results = await asyncio.gather(
            *(ws.send_json(frame) for ws in list(sockets)), return_exceptions=True
        )
        for ws, res in zip(list(sockets), results):
            if isinstance(res, Exception):
                self.remove(ws)

    async def send_to_user(self, user_id: int, msg_type: str, data: Any) -> None:
        await self._send(self._by_user.get(user_id, set()), msg_type, data)

    async def send_to_users(self, user_ids: list[int], msg_type: str, data: Any) -> None:
        sockets: set[WebSocket] = set()
        for uid in user_ids:
            sockets |= self._by_user.get(uid, set())
        await self._send(sockets, msg_type, data)

    async def send_to_role(self, role: Role, msg_type: str, data: Any) -> None:
        await self._send(self._by_role.get(role, set()), msg_type, data)

    async def send_to_topic(self, topic: str, msg_type: str, data: Any) -> None:
        await self._send(self._by_topic.get(topic, set()), msg_type, data)

    def connection_count(self) -> int:
        return len(self._principal)


hub = Hub()
router = APIRouter(tags=["realtime"])


@router.websocket("/ws")
async def websocket_endpoint(ws: WebSocket, token: str) -> None:
    try:
        principal = principal_from_token(token)
    except DomainError:
        await ws.close(code=4401)
        return
    await ws.accept()
    hub.add(ws, principal)
    try:
        while True:
            msg = await ws.receive_json()
            action = msg.get("action") if isinstance(msg, dict) else None
            topic = msg.get("topic") if isinstance(msg, dict) else None
            if action == "subscribe" and isinstance(topic, str):
                hub.subscribe(ws, topic)
            elif action == "unsubscribe" and isinstance(topic, str):
                hub.unsubscribe(ws, topic)
            elif action == "ping":
                await ws.send_json({"type": "pong", "data": {}})
    except WebSocketDisconnect:
        pass
    except Exception:  # noqa: BLE001
        log.exception("WebSocket error")
    finally:
        hub.remove(ws)
