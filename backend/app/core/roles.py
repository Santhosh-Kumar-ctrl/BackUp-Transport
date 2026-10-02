from enum import Enum


class Role(str, Enum):
    STUDENT = "student"
    DRIVER = "driver"
    ADMIN = "admin"
