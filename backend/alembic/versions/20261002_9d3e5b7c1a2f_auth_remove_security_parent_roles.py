"""auth: remove the security and parent roles

Neither role ever had screens of its own, so they are dropped: users.role allows only
student, driver and admin, and student_profiles.parent_user_id goes. Existing security and
parent accounts are deleted (their notifications go with them; allocations, boardings and
delay reports they recorded keep the row with the actor cleared). Downgrade restores the
column and the wider role list, not the deleted accounts.

Revision ID: 9d3e5b7c1a2f
Revises: 4f1c2d7a9b3e
Create Date: 2026-10-02 12:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '9d3e5b7c1a2f'
down_revision: Union[str, None] = '4f1c2d7a9b3e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_constraint(op.f('fk_student_profiles_parent_user_id_users'), 'student_profiles', type_='foreignkey')
    op.drop_column('student_profiles', 'parent_user_id')

    op.execute("DELETE FROM users WHERE role IN ('security', 'parent')")
    op.drop_constraint(op.f('ck_users_user_role'), 'users', type_='check')
    op.create_check_constraint(op.f('ck_users_user_role'), 'users', "role IN ('student', 'driver', 'admin')")


def downgrade() -> None:
    op.drop_constraint(op.f('ck_users_user_role'), 'users', type_='check')
    op.create_check_constraint(op.f('ck_users_user_role'), 'users',
                               "role IN ('student', 'driver', 'admin', 'security', 'parent')")

    op.add_column('student_profiles', sa.Column('parent_user_id', sa.Integer(), nullable=True))
    op.create_foreign_key(op.f('fk_student_profiles_parent_user_id_users'), 'student_profiles', 'users',
                          ['parent_user_id'], ['id'], ondelete='SET NULL')
