"""Alembic environment — nexus-controller.

Database URL is read exclusively from the NEXUS_DB_URL environment variable.
No secrets in config files (CLAUDE.md guardrail #3).
"""
import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

config = context.config

# Pull URL from env; fail loudly if missing so misconfigured runs don't silently
# operate against the wrong database.
db_url = os.environ.get("NEXUS_DB_URL")
if db_url:
    config.set_main_option("sqlalchemy.url", db_url)
else:
    raise RuntimeError(
        "NEXUS_DB_URL environment variable is not set. "
        "Export it before running alembic (see deploy/.env.template)."
    )

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Schema-only migrations; no ORM metadata to compare against.
target_metadata = None


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
