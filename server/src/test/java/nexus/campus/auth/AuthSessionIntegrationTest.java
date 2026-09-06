package nexus.campus.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import nexus.campus.auth.service.TokenService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.Map;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.doThrow;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
@Transactional
class AuthSessionIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper json;
    @MockitoSpyBean TokenService tokens;
    private static final String PASSWORD = "integration-test-password";

    private JsonNode register() throws Exception {
        var response = mvc.perform(post("/api/register").contentType("application/json").content(json.writeValueAsString(
            Map.of("username", "session-test", "email", "session-test@example.invalid", "password", PASSWORD))))
            .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return json.readTree(response).get("data");
    }
    private JsonNode login() throws Exception {
        return json.readTree(mvc.perform(post("/api/login").contentType("application/json").content(json.writeValueAsString(
            Map.of("identification", "session-test", "password", PASSWORD))))
            .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("data");
    }
    private void valid(String token) throws Exception {
        mvc.perform(get("/api/nexus/resources").param("scope", "mine").header("Authorization", "Token " + token))
            .andExpect(status().isOk());
    }
    private void invalid(String token) throws Exception {
        mvc.perform(get("/api/nexus/resources").param("scope", "mine").header("Authorization", "Token " + token))
            .andExpect(status().isUnauthorized());
    }
    @Test void registrationCreatesExpiringSessionAndEveryLoginIssuesFreshToken() throws Exception {
        var first = register();
        var second = login();
        assertNotEquals(first.get("token").asText(), second.get("token").asText());
        var expires = Instant.parse(second.get("expiresAt").asText());
        assertTrue(expires.isAfter(Instant.now().plusSeconds(6 * 86400)));
        assertTrue(expires.isBefore(Instant.now().plusSeconds(8 * 86400)));
        valid(first.get("token").asText()); valid(second.get("token").asText());
    }
    @Test void logoutRevokesOnlyPresentedTokenAndCannotBeReused() throws Exception {
        String first = register().get("token").asText();
        String second = login().get("token").asText();
        mvc.perform(post("/api/logout").header("Authorization", "Token " + first)).andExpect(status().isOk());
        invalid(first); valid(second);
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM api_keys WHERE token_key=?", Integer.class, first));
        mvc.perform(post("/api/logout").header("Authorization", "Token " + first)).andExpect(status().isUnauthorized());
        assertNotEquals(first, login().get("token").asText());
    }
    @Test void expiredAndLegacyTokensAreRejected() throws Exception {
        String token = register().get("token").asText();
        jdbc.update("UPDATE api_keys SET expires_at=? WHERE token_key=?", Timestamp.from(Instant.now().minusSeconds(1)), token);
        invalid(token);
        jdbc.update("UPDATE api_keys SET expires_at=NULL WHERE token_key=?", token);
        invalid(token);
        valid(login().get("token").asText());
    }
    @Test void unauthenticatedAndInvalidSessionsReturn401InsteadOf403() throws Exception {
        mvc.perform(post("/api/logout")).andExpect(status().isUnauthorized());
        invalid("not-a-token");
        mvc.perform(get("/api/nexus/me/agent-context")).andExpect(status().isUnauthorized());
    }
    @Test void databaseOutageIs503NotInvalidCredentials() throws Exception {
        doThrow(new DataAccessResourceFailureException("test outage")).when(tokens).findUserId("storage-down");
        mvc.perform(get("/api/nexus/me/agent-context").header("Authorization", "Token storage-down"))
            .andExpect(status().isServiceUnavailable())
            .andExpect(jsonPath("$.errors[0].message").value("Authentication service temporarily unavailable"));
    }
    @Test void incorrectPasswordDoesNotIssueSession() throws Exception {
        register();
        Integer before = jdbc.queryForObject("SELECT COUNT(*) FROM api_keys", Integer.class);
        mvc.perform(post("/api/login").contentType("application/json").content(json.writeValueAsString(
            Map.of("identification", "session-test", "password", "wrong-password"))))
            .andExpect(status().isBadRequest());
        assertEquals(before, jdbc.queryForObject("SELECT COUNT(*) FROM api_keys", Integer.class));
    }
}
