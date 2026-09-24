from dataclasses import dataclass

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.errors import Forbidden, Unauthorized
from app.core.roles import Role
from app.core.security import verify

_bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class Principal:
    """The authenticated caller, decoded from the access token (no DB hit).

    A deactivated user keeps access until their access token expires
    (ACCESS_TOKEN_MINUTES); refresh is refused for inactive users.
    """

    id: int
    role: Role

    def is_(self, *roles: Role) -> bool:
        return self.role in roles


def principal_from_token(token: str) -> Principal:
    claims = verify(token, "access")
    return Principal(id=int(claims["sub"]), role=Role(claims["role"]))


async def current_principal(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> Principal:
    if creds is None:
        raise Unauthorized("Not authenticated")
    return principal_from_token(creds.credentials)


def require_roles(*roles: Role):
    """Dependency factory: `Depends(require_roles(Role.ADMIN))`."""

    async def dep(p: Principal = Depends(current_principal)) -> Principal:
        if p.role not in roles:
            raise Forbidden(f"Requires role: {', '.join(r.value for r in roles)}")
        return p

    return dep
