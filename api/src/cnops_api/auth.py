"""JWT bearer auth with roles viewer < operator < admin (STANDARDS §5).

Local issuer now (HS256, secret from env). In the AWS phase the verifier
switches to Cognito's JWKS; routes do not change.
"""

from __future__ import annotations

import hmac
import time
import uuid
from collections import defaultdict, deque
from collections.abc import Callable
from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from cnops_api.models import Principal, Role, Token
from cnops_api.settings import Settings

RANK = {Role.VIEWER: 0, Role.OPERATOR: 1, Role.ADMIN: 2}
_bearer = HTTPBearer(auto_error=False, description="JWT from POST /v1/auth/token")


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(401, detail, headers={"WWW-Authenticate": 'Bearer realm="cnops"'})


class Authenticator:
    def __init__(self, settings: Settings) -> None:
        self._s = settings
        self._users: dict[str, tuple[str, Role]] = {}
        for entry in settings.dev_users.get_secret_value().split(","):
            if entry.strip():
                name, password, role = entry.strip().split(":", 2)
                self._users[name] = (password, Role(role))
        # OWASP API4: throttle login attempts per username.
        self._attempts: dict[str, deque[float]] = defaultdict(deque)
        self.max_attempts = 5
        self.window_s = 60.0

    def _throttled(self, username: str) -> bool:
        now = time.monotonic()
        q = self._attempts[username]
        while q and now - q[0] > self.window_s:
            q.popleft()
        if len(q) >= self.max_attempts:
            return True
        q.append(now)
        return False

    def login(self, username: str, password: str) -> Token:
        if self._throttled(username):
            raise HTTPException(
                429, "too many login attempts; wait a minute", headers={"Retry-After": "60"}
            )
        stored = self._users.get(username)
        # Compare against a dummy when the user is unknown: same timing either way.
        expected = stored[0] if stored else "x" * 32
        if not hmac.compare_digest(password.encode(), expected.encode()) or stored is None:
            raise _unauthorized("invalid username or password")
        self._attempts.pop(username, None)
        return self.issue(username, stored[1])

    def issue(self, subject: str, role: Role, ttl: int | None = None) -> Token:
        now = int(time.time())
        ttl = ttl if ttl is not None else self._s.jwt_ttl_seconds
        claims = {
            "sub": subject,
            "role": role.value,
            "iss": self._s.jwt_issuer,
            "aud": self._s.jwt_audience,
            "iat": now,
            "nbf": now,
            "exp": now + ttl,
            "jti": uuid.uuid4().hex,
        }
        token = jwt.encode(claims, self._s.jwt_secret.get_secret_value(), algorithm="HS256")
        return Token(access_token=token, expires_in=ttl, role=role)

    def verify(self, token: str) -> Principal:
        try:
            claims = jwt.decode(
                token,
                self._s.jwt_secret.get_secret_value(),
                algorithms=["HS256"],  # never accept "none" or a caller-chosen alg
                audience=self._s.jwt_audience,
                issuer=self._s.jwt_issuer,
                options={"require": ["exp", "iat", "sub", "role"]},
            )
            return Principal(subject=str(claims["sub"]), role=Role(claims["role"]))
        except (jwt.PyJWTError, ValueError) as exc:
            raise _unauthorized(f"invalid token: {exc}") from exc


def get_authenticator(request: Request) -> Authenticator:
    auth: Authenticator = request.app.state.container.auth
    return auth


def current_principal(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
    auth: Annotated[Authenticator, Depends(get_authenticator)],
) -> Principal:
    if creds is None or creds.scheme.lower() != "bearer":
        raise _unauthorized("missing bearer token")
    return auth.verify(creds.credentials)


def require(role: Role) -> Callable[[Principal], Principal]:
    def checker(principal: Annotated[Principal, Depends(current_principal)]) -> Principal:
        if RANK[principal.role] < RANK[role]:
            raise HTTPException(
                403, f"requires role '{role.value}' (you are '{principal.role.value}')"
            )
        return principal

    return checker


Viewer = Annotated[Principal, Depends(require(Role.VIEWER))]
Operator = Annotated[Principal, Depends(require(Role.OPERATOR))]
Admin = Annotated[Principal, Depends(require(Role.ADMIN))]
