"""tracking: live positions and approach alerts

bus_positions moves from trips to the new tracking module (same table) and gains heading,
accuracy and a (trip_id, recorded_at) index; approach_alerts is new.

Revision ID: 4f1c2d7a9b3e
Revises: 760c6592a8a4
Create Date: 2026-09-29 10:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '4f1c2d7a9b3e'
down_revision: Union[str, None] = '760c6592a8a4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('bus_positions', sa.Column('heading_deg', sa.Float(), nullable=True))
    op.add_column('bus_positions', sa.Column('accuracy_m', sa.Float(), nullable=True))
    op.drop_index(op.f('ix_bus_positions_trip_id'), table_name='bus_positions')
    op.create_index('ix_bus_positions_trip_recorded', 'bus_positions', ['trip_id', 'recorded_at'], unique=False)

    op.create_table('approach_alerts',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('trip_id', sa.Integer(), nullable=False),
    sa.Column('stop_id', sa.Integer(), nullable=False),
    sa.Column('sequence', sa.SmallInteger(), nullable=False),
    sa.Column('distance_m', sa.Integer(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['stop_id'], ['stops.id'], name=op.f('fk_approach_alerts_stop_id_stops'), ondelete='RESTRICT'),
    sa.ForeignKeyConstraint(['trip_id'], ['trips.id'], name=op.f('fk_approach_alerts_trip_id_trips'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_approach_alerts')),
    sa.UniqueConstraint('trip_id', 'stop_id', name='uq_approach_alerts_trip_stop')
    )


def downgrade() -> None:
    op.drop_table('approach_alerts')
    op.drop_index('ix_bus_positions_trip_recorded', table_name='bus_positions')
    op.create_index(op.f('ix_bus_positions_trip_id'), 'bus_positions', ['trip_id'], unique=False)
    op.drop_column('bus_positions', 'accuracy_m')
    op.drop_column('bus_positions', 'heading_deg')
