from enum import Enum


class Role(str, Enum):
    STUDENT = "student"
    DRIVER = "driver"
    ADMIN = "admin"
    SECURITY = "security"  # role exists in P0; screens come in P1
    PARENT = "parent"  # role exists in P0; screens come in P1
