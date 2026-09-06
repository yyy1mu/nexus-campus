package nexus.campus.catalog;

import com.fasterxml.jackson.databind.ObjectMapper;
import nexus.campus.common.entity.User;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.web.authentication.preauth.PreAuthenticatedAuthenticationToken;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.Map;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.hamcrest.Matchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
@Transactional
class CatalogIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    private RequestPostProcessor as(int id) {
        var user = new User(); user.setId(id);
        return authentication(new PreAuthenticatedAuthenticationToken(user, "test", List.of()));
    }
    private Map<String, String> skill() {
        return Map.of("kind", "skill", "name", "Vue practices", "category", "开发工具",
            "summary", "Reusable Vue guidance", "description", "Use the source documentation",
            "sourceUrl", "https://github.com/example/skills", "installCommand", "npx skills add example/skills",
            "endpoint", "", "transport", "", "authType", "");
    }
    private int createSkill() throws Exception {
        var result = mvc.perform(post("/api/nexus/resources").with(as(11)).contentType("application/json")
            .content(json.writeValueAsString(skill()))).andExpect(status().isOk()).andReturn();
        return json.readTree(result.getResponse().getContentAsString()).at("/data/id").asInt();
    }
    @Test void publicBrowsingReturnsOnlyPublicFieldsAndSearches() throws Exception {
        int id = createSkill();
        mvc.perform(get("/api/nexus/resources").param("q", "Vue"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.total").value(1))
            .andExpect(jsonPath("$.data.items[0].editable").value(false))
            .andExpect(jsonPath("$.data.items[0].favorites").doesNotExist())
            .andExpect(jsonPath("$.data.items[0].token").doesNotExist());
        mvc.perform(get("/api/nexus/resources/{id}", id)).andExpect(status().isOk());
        mvc.perform(get("/api/nexus/resources").param("q", "%"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.total").value(0));
    }
    @Test void categoryFilterCombinesWithSearchAndPersonalScope() throws Exception {
        int id = createSkill();
        mvc.perform(put("/api/nexus/resources/{id}/favorite", id).with(as(12)))
            .andExpect(status().isOk());
        mvc.perform(get("/api/nexus/resources").param("category", "开发工具").param("q", "Vue")
            .param("scope", "favorites").with(as(12)))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.total").value(1));
        mvc.perform(get("/api/nexus/resources").param("category", "数据分析"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.total").value(0));
        mvc.perform(get("/api/nexus/resources").param("category", "开发工具").param("q", "missing"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.total").value(0));
    }
    @Test void anonymousCannotWriteOrReadPersonalCollection() throws Exception {
        mvc.perform(post("/api/nexus/resources").contentType("application/json").content(json.writeValueAsString(skill())))
            .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/nexus/resources").param("scope", "favorites"))
            .andExpect(status().isUnauthorized());
    }
    @Test void onlyOwnerCanUpdateAndDelete() throws Exception {
        int id = createSkill();
        mvc.perform(put("/api/nexus/resources/{id}", id).with(as(12)).contentType("application/json")
            .content(json.writeValueAsString(skill()))).andExpect(status().isForbidden());
        mvc.perform(delete("/api/nexus/resources/{id}", id).with(as(12))).andExpect(status().isForbidden());
        mvc.perform(put("/api/nexus/resources/{id}", id).with(as(11)).contentType("application/json")
            .content(json.writeValueAsString(skill()))).andExpect(status().isOk());
        mvc.perform(delete("/api/nexus/resources/{id}", id).with(as(11))).andExpect(status().isOk());
        mvc.perform(get("/api/nexus/resources/{id}", id)).andExpect(status().isNotFound());
    }
    @Test void favoritesAreIdempotentAndPrivateToViewer() throws Exception {
        int id = createSkill();
        for (int i = 0; i < 2; i++) mvc.perform(put("/api/nexus/resources/{id}/favorite", id).with(as(12)))
            .andExpect(status().isOk()).andExpect(jsonPath("$.data.favoriteCount").value(1));
        mvc.perform(get("/api/nexus/resources").param("scope", "favorites").with(as(12)))
            .andExpect(jsonPath("$.data.total").value(1)).andExpect(jsonPath("$.data.items[0].favorited").value(true));
        mvc.perform(get("/api/nexus/resources").param("scope", "favorites").with(as(11)))
            .andExpect(jsonPath("$.data.total").value(0));
        mvc.perform(delete("/api/nexus/resources/{id}/favorite", id).with(as(12)))
            .andExpect(jsonPath("$.data.favoriteCount").value(0));
    }
    @Test void validatesInputAndNeverAcceptsCredentialsInAddresses() throws Exception {
        var input = new java.util.HashMap<>(skill());
        input.put("kind", "mcp"); input.put("transport", "streamable-http"); input.put("authType", "bearer");
        input.put("endpoint", "https://example.com/mcp?token=secret");
        mvc.perform(post("/api/nexus/resources").with(as(11)).contentType("application/json")
            .content(json.writeValueAsString(input))).andExpect(status().isBadRequest());
        input.put("endpoint", "https://example.com/mcp");
        mvc.perform(post("/api/nexus/resources").with(as(11)).contentType("application/json")
            .content(json.writeValueAsString(input))).andExpect(status().isOk())
            .andExpect(jsonPath("$.data.authType").value("bearer"));
        input.put("sourceUrl", "javascript:alert(1)");
        mvc.perform(post("/api/nexus/resources").with(as(11)).contentType("application/json")
            .content(json.writeValueAsString(input))).andExpect(status().isBadRequest());
        input.put("name", " ");
        mvc.perform(post("/api/nexus/resources").with(as(11)).contentType("application/json")
            .content(json.writeValueAsString(input))).andExpect(status().isBadRequest());
    }
    @Test void rejectsInvalidScopeAndLocalBearerTransport() throws Exception {
        mvc.perform(get("/api/nexus/resources").param("kind", "unknown")).andExpect(status().isBadRequest());
        mvc.perform(get("/api/nexus/resources").param("page", "-1")).andExpect(status().isBadRequest());
        var input = new java.util.HashMap<>(skill());
        input.put("kind", "mcp"); input.put("transport", "stdio"); input.put("authType", "bearer");
        mvc.perform(post("/api/nexus/resources").with(as(11)).contentType("application/json")
            .content(json.writeValueAsString(input))).andExpect(status().isBadRequest());
    }
}
