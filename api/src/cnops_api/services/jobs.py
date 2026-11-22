"""Terraform jobs: one worker thread, so applies never overlap. Every change
(rule or subnet) gets the job ID; when the job ends their status becomes
applied / planned / failed and the outcome is written to the audit log."""

from __future__ import annotations

import logging
import queue
import re
import threading
import uuid
from collections.abc import Callable
from datetime import UTC, datetime

from cnops_api.adapters.terraform import TerraformRunner
from cnops_api.errors import NotFoundError
from cnops_api.models import ChangeStatus, Job, JobState

log = logging.getLogger(__name__)
SUMMARY = re.compile(r"^(Plan: .*|No changes\..*|Apply complete!.*|Error: .*)$", re.MULTILINE)
Callback = Callable[[Job, ChangeStatus], None]


class JobRunner:
    def __init__(self, terraform: TerraformRunner, synchronous: bool = False) -> None:
        self._tf = terraform
        self._sync = synchronous
        self._jobs: dict[str, Job] = {}
        self._callbacks: dict[str, list[Callback]] = {}
        self._queue: queue.Queue[str | None] = queue.Queue()
        self._lock = threading.Lock()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if self._sync or self._thread is not None:
            return
        self._thread = threading.Thread(target=self._worker, name="terraform-jobs", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        if self._thread is not None:
            self._queue.put(None)
            self._thread.join(timeout=5)
            self._thread = None

    def submit(self, reason: str, on_done: Callback) -> Job:
        job = Job(
            id=f"job-{uuid.uuid4().hex[:8]}",
            kind="terraform",
            mode=self._tf.mode,
            state=JobState.QUEUED,
            reason=reason,
            created_at=datetime.now(UTC),
        )
        with self._lock:
            self._jobs[job.id] = job
            self._callbacks[job.id] = [on_done]
        if self._sync:
            self._execute(job.id)
        else:
            self._queue.put(job.id)
        return self.get(job.id)  # latest state (already finished in synchronous mode)

    def get(self, job_id: str) -> Job:
        with self._lock:
            job = self._jobs.get(job_id)
        if job is None:
            raise NotFoundError("job", job_id)
        return job

    def _worker(self) -> None:
        while (job_id := self._queue.get()) is not None:
            try:
                self._execute(job_id)
            except Exception:
                log.exception("job crashed", extra={"fields": {"job_id": job_id}})

    def _execute(self, job_id: str) -> None:
        with self._lock:
            self._jobs[job_id] = self._jobs[job_id].model_copy(update={"state": JobState.RUNNING})
        result = self._tf.run()
        if not result.ok:
            outcome = ChangeStatus.FAILED
        elif self._tf.mode == "plan":
            outcome = ChangeStatus.PLANNED
        else:
            outcome = ChangeStatus.APPLIED
        with self._lock:
            job = self._jobs[job_id].model_copy(
                update={
                    "state": JobState.SUCCEEDED if result.ok else JobState.FAILED,
                    "finished_at": datetime.now(UTC),
                    "summary": next(iter(SUMMARY.findall(result.output)), None),
                    "output_tail": result.output[-2000:],
                }
            )
            self._jobs[job_id] = job
            callbacks = self._callbacks.pop(job_id, [])
        log.info(
            "terraform job finished",
            extra={"fields": {"job_id": job_id, "state": job.state, "mode": job.mode}},
        )
        for cb in callbacks:
            cb(job, outcome)
