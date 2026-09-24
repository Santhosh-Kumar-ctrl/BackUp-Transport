"""Periodic background jobs registered by modules, started/stopped by the app lifespan.

    tasks.every(60, "delay-watcher", watch_active_trips)
"""

import asyncio
import logging
from collections.abc import Awaitable, Callable
from dataclasses import dataclass

log = logging.getLogger("transit.tasks")


@dataclass
class PeriodicJob:
    name: str
    interval_seconds: float
    fn: Callable[[], Awaitable[None]]


_jobs: dict[str, PeriodicJob] = {}
_running: list[asyncio.Task] = []


def every(interval_seconds: float, name: str, fn: Callable[[], Awaitable[None]]) -> None:
    _jobs[name] = PeriodicJob(name, interval_seconds, fn)


def registered() -> list[PeriodicJob]:
    return list(_jobs.values())


async def _loop(job: PeriodicJob) -> None:
    while True:
        try:
            await job.fn()
        except asyncio.CancelledError:
            raise
        except Exception:  # noqa: BLE001
            log.exception("Periodic job %s failed", job.name)
        await asyncio.sleep(job.interval_seconds)


def start_all() -> None:
    for job in _jobs.values():
        _running.append(asyncio.create_task(_loop(job), name=f"job:{job.name}"))


async def stop_all() -> None:
    for t in _running:
        t.cancel()
    await asyncio.gather(*_running, return_exceptions=True)
    _running.clear()
