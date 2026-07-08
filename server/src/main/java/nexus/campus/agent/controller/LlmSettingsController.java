package nexus.campus.agent.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.agent.entity.UserLlmSettings;
import nexus.campus.agent.repository.UserLlmSettingsRepository;
import nexus.campus.common.entity.User;
import nexus.campus.common.exception.ApiException;
import nexus.campus.common.response.ApiResponse;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class LlmSettingsController {

    private final UserLlmSettingsRepository settingsRepository;

    @GetMapping("/llm-settings")
    public ApiResponse<Map<String, Object>> show(@AuthenticationPrincipal User user) {
        var row = settingsRepository.findById(user.getId()).orElse(new UserLlmSettings());
        boolean apiKeySet = row.getApiKey() != null && !row.getApiKey().isBlank();
        var attrs = new LinkedHashMap<String, Object>();
        attrs.put("provider", Objects.requireNonNullElse(row.getProvider(), "builtin"));
        attrs.put("chatModel", row.getChatModel());
        attrs.put("apiKeySet", apiKeySet);
        attrs.put("apiKeyPreview", previewKey(row.getApiKey()));
        attrs.put("supportsChatCompletions", row.isSupportsChatCompletions());
        attrs.put("supportsResponses", row.isSupportsResponses());
        return ApiResponse.ok(attrs);
    }

    @PatchMapping("/llm-settings")
    public ApiResponse<Map<String, Object>> update(
            @AuthenticationPrincipal User user, @RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        var attrs = (Map<String, Object>) ((Map<String, Object>) body.get("data"))
                .getOrDefault("attributes", body);
        if (!Boolean.TRUE.equals(attrs.get("userConfirmed")))
            throw ApiException.badRequest("userConfirmed", "Confirmation required.");

        var row = settingsRepository.findById(user.getId()).orElseGet(() -> {
            var s = new UserLlmSettings(); s.setUserId(user.getId()); return s;
        });
        if (attrs.containsKey("provider")) row.setProvider((String) attrs.get("provider"));
        if (attrs.containsKey("baseUrl")) row.setBaseUrl((String) attrs.get("baseUrl"));
        if (attrs.containsKey("chatModel")) row.setChatModel((String) attrs.get("chatModel"));
        if (attrs.containsKey("apiKey")) row.setApiKey((String) attrs.get("apiKey"));
        settingsRepository.save(row);
        return show(user);
    }

    private String previewKey(String key) {
        if (key == null || key.isEmpty()) return "";
        if (key.length() <= 8) return "*".repeat(key.length());
        return key.substring(0, 4) + "*".repeat(Math.max(key.length() - 8, 4)) + key.substring(key.length() - 4);
    }
}
