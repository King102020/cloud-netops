"""HTTP layer only: parse, authorise, call a service, shape the response."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Query, Request

from cnops_api.container import Container


def get_container(request: Request) -> Container:
    container: Container = request.app.state.container
    return container


Deps = Annotated[Container, Depends(get_container)]
Limit = Annotated[int, Query(ge=1, le=100, description="Page size")]
Cursor = Annotated[
    str | None, Query(max_length=512, description="next_cursor from the previous page")
]
