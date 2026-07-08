package nexus.campus.auth.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import nexus.campus.common.exception.ApiException;
import nexus.campus.auth.dto.LoginRequest;
import nexus.campus.auth.dto.RegisterRequest;
import nexus.campus.auth.dto.TokenResponse;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.sql.DataSource;
import java.security.SecureRandom;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.time.LocalDateTime;
import java.util.HexFormat;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {
    private final DataSource dataSource;
    private final PasswordEncoder passwordEncoder;
    private final SecureRandom secureRandom = new SecureRandom();

    @Transactional
    public TokenResponse register(RegisterRequest req) {
        try (Connection conn = dataSource.getConnection()) {
            if (userExists(conn, req.getUsername(), req.getEmail())) {
                throw ApiException.badRequest("username", "Username or email already taken.");
            }
            int userId = insertUser(conn, req.getUsername(), req.getEmail(),
                    passwordEncoder.encode(req.getPassword()));
            String token = generateAndInsertToken(conn, userId);
            return TokenResponse.builder().token(token).userId(userId).username(req.getUsername()).build();
        } catch (ApiException e) { throw e;
        } catch (Exception e) { throw new RuntimeException("Registration failed", e); }
    }

    @Transactional
    public TokenResponse login(LoginRequest req) {
        try (Connection conn = dataSource.getConnection()) {
            var creds = findUserCredentials(conn, req.getIdentification());
            if (creds == null || !passwordEncoder.matches(req.getPassword(), creds.password())) {
                throw ApiException.badRequest("identification", "Invalid credentials.");
            }
            String token = findOrCreateToken(conn, creds.userId());
            return TokenResponse.builder().token(token).userId(creds.userId()).username(creds.username()).build();
        } catch (ApiException e) { throw e;
        } catch (Exception e) { throw new RuntimeException("Login failed", e); }
    }

    public record UserCreds(int userId, String username, String password) {}

    private boolean userExists(Connection conn, String username, String email) throws Exception {
        try (var ps = conn.prepareStatement("SELECT COUNT(*) FROM users WHERE username = ? OR email = ?")) {
            ps.setString(1, username); ps.setString(2, email);
            try (var rs = ps.executeQuery()) { return rs.next() && rs.getInt(1) > 0; }
        }
    }

    private int insertUser(Connection conn, String username, String email, String hash) throws Exception {
        try (var ps = conn.prepareStatement(
                "INSERT INTO users (username, email, password, joined_at, is_email_confirmed) VALUES (?,?,?,?,1)",
                Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, username); ps.setString(2, email);
            ps.setString(3, hash); ps.setString(4, LocalDateTime.now().toString().replace("T", " "));
            ps.executeUpdate();
            try (var keys = ps.getGeneratedKeys()) {
                keys.next();
                return keys.getInt(1);
            }
        }
    }

    private UserCreds findUserCredentials(Connection conn, String identification) throws Exception {
        try (var ps = conn.prepareStatement(
                "SELECT id, username, password FROM users WHERE username = ? OR email = ?")) {
            ps.setString(1, identification); ps.setString(2, identification);
            try (var rs = ps.executeQuery()) {
                if (rs.next()) return new UserCreds(rs.getInt("id"), rs.getString("username"), rs.getString("password"));
            }
        }
        return null;
    }

    private String generateAndInsertToken(Connection conn, int userId) throws Exception {
        byte[] bytes = new byte[20]; secureRandom.nextBytes(bytes);
        String key = HexFormat.of().formatHex(bytes);
        try (var ps = conn.prepareStatement(
                "INSERT INTO api_keys (token_key, user_id, created_at) VALUES (?, ?, ?)")) {
            ps.setString(1, key); ps.setInt(2, userId); ps.setString(3, LocalDateTime.now().toString().replace("T", " "));
            ps.executeUpdate();
        }
        return key;
    }

    private String findOrCreateToken(Connection conn, int userId) throws Exception {
        try (var ps = conn.prepareStatement(
                "SELECT token_key FROM api_keys WHERE user_id = ? ORDER BY created_at DESC LIMIT 1")) {
            ps.setInt(1, userId);
            try (var rs = ps.executeQuery()) {
                if (rs.next()) return rs.getString("token_key");
            }
        }
        return generateAndInsertToken(conn, userId);
    }
}
