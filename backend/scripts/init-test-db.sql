-- Runs once when the Postgres volume is first created: a separate DB for pytest.
CREATE DATABASE transit_test OWNER transit;
