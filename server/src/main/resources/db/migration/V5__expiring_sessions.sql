-- NULL expires_at deliberately invalidates legacy tokens. Users must sign in again.
ALTER TABLE api_keys ADD COLUMN expires_at TIMESTAMP(6) NULL;
