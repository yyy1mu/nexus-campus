package nexus.campus.auth.service;

import lombok.RequiredArgsConstructor;
import nexus.campus.common.exception.ApiException;
import nexus.campus.auth.dto.LoginRequest;
import nexus.campus.auth.dto.RegisterRequest;
import nexus.campus.auth.dto.TokenResponse;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Statement;
import java.sql.Timestamp;
import java.time.Instant;

@Service
@RequiredArgsConstructor
public class AuthService {
    private final JdbcTemplate jdbc;
    private final PasswordEncoder passwordEncoder;
    private final TokenService tokens;

    @Transactional
    public TokenResponse register(RegisterRequest req) {
        Integer count = jdbc.queryForObject("SELECT COUNT(*) FROM users WHERE username=? OR email=?",
            Integer.class, req.getUsername(), req.getEmail());
        if (count != null && count > 0) throw ApiException.badRequest("username", "Username or email already taken.");
        String hash = passwordEncoder.encode(req.getPassword());
        var key = new GeneratedKeyHolder();
        try {
            jdbc.update(conn -> {
                var statement = conn.prepareStatement(
                    "INSERT INTO users (username, email, password, joined_at, is_email_confirmed) VALUES (?,?,?,?,1)",
                    Statement.RETURN_GENERATED_KEYS);
                statement.setString(1, req.getUsername());
                statement.setString(2, req.getEmail());
                statement.setString(3, hash);
                statement.setTimestamp(4, Timestamp.from(Instant.now()));
                return statement;
            }, key);
        } catch (DuplicateKeyException e) {
            throw ApiException.badRequest("username", "Username or email already taken.");
        }
        if (key.getKey() == null) throw new IllegalStateException("User insert did not return an ID");
        return session(key.getKey().intValue(), req.getUsername());
    }

    @Transactional
    public TokenResponse login(LoginRequest req) {
        var users = jdbc.query("SELECT id, username, password FROM users WHERE username=? OR email=?",
            (rs, row) -> new UserCreds(rs.getInt("id"), rs.getString("username"), rs.getString("password")),
            req.getIdentification(), req.getIdentification());
        if (users.size() != 1 || !passwordEncoder.matches(req.getPassword(), users.getFirst().password()))
            throw ApiException.badRequest("identification", "Invalid credentials.");
        var user = users.getFirst();
        return session(user.userId(), user.username());
    }

    private TokenResponse session(int userId, String username) {
        var token = tokens.issue(userId);
        return TokenResponse.builder().token(token.value()).expiresAt(token.expiresAt())
            .userId(userId).username(username).build();
    }

    private record UserCreds(int userId, String username, String password) {}
}
