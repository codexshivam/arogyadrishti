"""Role and Palika/Ward Attribute-Based Access Control (ABAC) dependencies for Government of Nepal."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from enum import StrEnum
from typing import Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.security import verify_asymmetric_jwt


class NepalStaffRole(StrEnum):
    """Statutory municipal and federal health surveillance roles in Nepal."""

    FCHV = "fchv"  # महिला सामुदायिक स्वास्थ्य स्वयंसेविका (Ward-scoped)
    WARD_HEALTH_OFFICER = "ward_health_officer"  # HA / AHW / Ward Sanitary Inspector at Ward BHSC/UHPC
    PALIKA_HEALTH_CHIEF = "palika_health_chief"  # Chief of Municipal Public Health Division (Jan Swasthya Bibhag)
    EDCD_NODAL = "edcd_nodal"  # Federal MoHP / EDCD Teku / Provincial Health Directorate Officer


@dataclass(frozen=True)
class AuthenticatedStaffPrincipal:
    """Verified staff identity extracted from an asymmetric EdDSA JWT."""

    sub: str
    jti: str
    role: NepalStaffRole
    province_code: int
    district_code: int
    palika_code: str
    assigned_wards: list[str]
    iat: int
    exp: int

    def can_access_palika(self, target_palika_code: str) -> bool:
        if self.role == NepalStaffRole.EDCD_NODAL:
            return True
        return str(self.palika_code) == str(target_palika_code)

    def can_access_ward(self, composite_ward_id: str, target_palika_code: str | None = None) -> bool:
        """
        Enforce Constitution of Nepal Schedule 8 & Local Government Operation Act 2074 isolation:
        - edcd_nodal: read-only access across all Palikas/Wards
        - palika_health_chief: full access to all wards within their assigned palika_code
        - ward_health_officer / fchv: strictly isolated to their assigned_wards list
        """
        if self.role == NepalStaffRole.EDCD_NODAL:
            return True

        # Extract palika_code from composite_ward_id (e.g. NP-P3-D27-30608-W17 -> 30608)
        inferred_palika = target_palika_code
        if not inferred_palika and composite_ward_id.startswith("NP-"):
            parts = composite_ward_id.split("-")
            if len(parts) >= 4:
                inferred_palika = parts[3]

        if inferred_palika and str(inferred_palika) != str(self.palika_code):
            return False

        if self.role == NepalStaffRole.PALIKA_HEALTH_CHIEF:
            return True

        return composite_ward_id in self.assigned_wards

    def can_mutate_ward(self, composite_ward_id: str, target_palika_code: str | None = None) -> bool:
        """EDCD Nodal officers have read-only national telemetry access; mutations require Palika/Ward jurisdiction."""
        if self.role == NepalStaffRole.EDCD_NODAL:
            return False
        return self.can_access_ward(composite_ward_id, target_palika_code)


_bearer_scheme = HTTPBearer(auto_error=False)


async def get_current_staff(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> AuthenticatedStaffPrincipal:
    """Validate EdDSA Bearer token and construct AuthenticatedStaffPrincipal."""
    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Bearer authentication token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        claims = verify_asymmetric_jwt(credentials.credentials, expected_type="access")
        role_enum = NepalStaffRole(str(claims["role"]))
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired EdDSA JWT: {exc}",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    return AuthenticatedStaffPrincipal(
        sub=str(claims["sub"]),
        jti=str(claims["jti"]),
        role=role_enum,
        province_code=int(claims["province_code"]),
        district_code=int(claims["district_code"]),
        palika_code=str(claims["palika_code"]),
        assigned_wards=[str(w) for w in claims.get("assigned_wards", [])],
        iat=int(claims["iat"]),
        exp=int(claims["exp"]),
    )


def require_roles(*allowed_roles: NepalStaffRole) -> Callable[..., Any]:
    """FastAPI dependency factory restricting an endpoint to specific NepalStaffRole values."""

    async def _role_guard(
        principal: AuthenticatedStaffPrincipal = Depends(get_current_staff),
    ) -> AuthenticatedStaffPrincipal:
        if principal.role not in allowed_roles:
            allowed_str = ", ".join(r.value for r in allowed_roles)
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    f"RBAC Forbidden: Role '{principal.role.value}' is not authorized for this operation. "
                    f"Required role(s): [{allowed_str}]."
                ),
            )
        return principal

    return _role_guard


def enforce_ward_isolation(
    principal: AuthenticatedStaffPrincipal,
    composite_ward_id: str,
    *,
    allow_read_only_nodal: bool = False,
) -> None:
    """Raise 403 Forbidden if principal attempts to access or mutate outside assigned Palika/Ward."""
    allowed = (
        principal.can_access_ward(composite_ward_id)
        if allow_read_only_nodal
        else principal.can_mutate_ward(composite_ward_id)
    )
    if not allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                f"Constitutional Schedule 8 / Palika ABAC Isolation Violation: "
                f"Staff '{principal.sub}' (role={principal.role.value}, palika={principal.palika_code}, "
                f"wards={principal.assigned_wards}) cannot access/mutate '{composite_ward_id}'."
            ),
        )
