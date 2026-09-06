package nexus.campus.auth.service;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class TokenService {
    private final JdbcTemplate jdbc;
    private final SecureRandom random = new SecureRandom();
    @Value("${nexus.auth.token-ttl:7d}")
    private Duration tokenTtl;

    public record IssuedToken(String value, Instant expiresAt) {}

    @Transactional
    public IssuedToken issue(int userId) {
        if (tokenTtl.isNegative() || tokenTtl.isZero()) throw new IllegalStateException("Token TTL must be positive");
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        String token = HexFormat.of().formatHex(bytes);
        Instant now = Instant.now();
        Instant expiresAt = now.plus(tokenTtl);
        jdbc.update("INSERT INTO api_keys (token_key, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)",
            token, userId, Timestamp.from(now), Timestamp.from(expiresAt));
        return new IssuedToken(token, expiresAt);
    }

    public Optional<Integer> findUserId(String token) {
        // Legacy keys without an expiration are deliberately not accepted.
        return jdbc.query("SELECT k.user_id FROM api_keys k JOIN users u ON u.id=k.user_id "
                + "WHERE k.token_key=? AND k.expires_at > ?",
            (rs, row) -> rs.getInt("user_id"), token, Timestamp.from(Instant.now())).stream().findFirst();
    }

    @Transactional
    public void revoke(String token) {
        jdbc.update("DELETE FROM api_keys WHERE token_key=?", token);
    }
}
