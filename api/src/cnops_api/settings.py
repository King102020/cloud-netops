"""Configuration from environment variables (prefix CNOPS_) and .env.

Defaults are the safe local ones. Nothing here may point at real AWS: the
AWS endpoint is validated to be a local address, like the Terraform env.
"""

from __future__ import annotations

import re
from enum import StrEnum
from functools import lru_cache
from pathlib import Path

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

REPO_ROOT = Path(__file__).resolve().parents[3]
LOCAL_ENDPOINT = re.compile(
    r"^https?://(localhost|127\.0\.0\.1|localstack|host\.docker\.internal|localhost\.localstack\.cloud)(:\d+)?/?$"
)


class AdapterMode(StrEnum):
    """`real` talks to Docker / Terraform / DynamoDB; `fake` is in-memory (tests, demos)."""

    REAL = "real"
    FAKE = "fake"


class TerraformMode(StrEnum):
    APPLY = "apply"  # terraform apply (LocalStack must be running)
    PLAN = "plan"  # terraform plan only: proves the change without applying it
    FAKE = "fake"  # no terraform at all (tests)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="CNOPS_", env_file=".env", extra="ignore")

    env: str = "local"
    log_level: str = "INFO"

    # ---- Auth (local issuer; Cognito in the AWS phase) ----
    jwt_secret: SecretStr = SecretStr("change-me-local-only")
    jwt_issuer: str = "cnops-local"
    jwt_audience: str = "cnops-api"
    jwt_ttl_seconds: int = Field(default=3600, ge=60, le=86_400)
    # Local demo users: "name:password:role" separated by commas.
    dev_users: SecretStr = SecretStr(
        "viewer:viewer-local:viewer,operator:operator-local:operator,admin:admin-local:admin"
    )

    # ---- Adapters ----
    lab_mode: AdapterMode = AdapterMode.REAL
    lab_prefix: str = "clab-cnops-"
    store_mode: AdapterMode = AdapterMode.FAKE
    terraform_mode: TerraformMode = TerraformMode.PLAN
    terraform_dir: Path = REPO_ROOT / "infra" / "envs" / "local"
    terraform_bin: str = "terraform"
    terraform_timeout_seconds: int = 900

    # ---- DynamoDB on LocalStack ----
    aws_endpoint_url: str = "http://localhost:4566"
    aws_region: str = "ap-south-1"
    audit_table: str = "cnops-local-audit-log"
    idempotency_table: str = "cnops-local-idempotency"

    # ---- CORS: the Flutter web build runs on another localhost port ----
    cors_origins: list[str] = ["http://localhost:8080", "http://127.0.0.1:8080"]

    @field_validator("aws_endpoint_url")
    @classmethod
    def _local_only(cls, v: str) -> str:
        if not LOCAL_ENDPOINT.match(v):
            msg = "aws_endpoint_url must be a local address (no real AWS before the AWS phase)"
            raise ValueError(msg)
        return v

    @property
    def managed_dir(self) -> Path:
        """Folder Terraform reads API-managed inputs from (git-ignored)."""
        return self.terraform_dir / ".cnops"


@lru_cache
def get_settings() -> Settings:
    return Settings()
