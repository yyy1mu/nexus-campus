package nexus.campus.agent.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.agent.entity.UserLlmSettings;
import nexus.campus.agent.repository.UserLlmSettingsRepository;
import nexus.campus.common.entity.User;
import nexus.campus.common.exception.ApiException;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.security.authorization.AgentWriteGuard;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class LlmSettingsController {

    private final UserLlmSettingsRepository settingsRepository;
    private final AgentWriteGuard guard;

    @GetMapping("/llm-settings")
    public ApiResponse<Map<String, Object>> show(@AuthenticationPrincipal User user) {
        var row = settingsRepository.findById(user.getId()).orElse(new UserLlmSettings());
        boolean apiKeySet = row.getApiKey() != null && !row.getApiKey().isBlank();
        var attrs = new LinkedHashMap<String, Object>();
        attrs.put("provider", Objects.requireNonNullElse(row.getProvider(), "builtin"));
        attrs.put("baseUrl", row.getBaseUrl());
        attrs.put("chatModel", row.getChatModel());
        attrs.put("responsesModel", row.getResponsesModel());
        attrs.put("apiKeySet", apiKeySet);
        attrs.put("apiKeyPreview", previewKey(row.getApiKey()));
        attrs.put("supportsChatCompletions", row.isSupportsChatCompletions());
        attrs.put("supportsResponses", row.isSupportsResponses());
        return ApiResponse.ok(attrs);
    }

    @PatchMapping("/llm-settings")
    public ApiResponse<Map<String, Object>> update(
            @AuthenticationPrincipal User user, @RequestBody Map<String, Object> body) {
        guard.requireConfirmedUser(user, body);

        var row = settingsRepository.findById(user.getId()).orElseGet(() -> {
            var s = new UserLlmSettings(); s.setUserId(user.getId()); return s;
        });
        if (body.containsKey("provider")) row.setProvider((String) body.get("provider"));
        if (body.containsKey("baseUrl")) row.setBaseUrl((String) body.get("baseUrl"));
        if (body.containsKey("chatModel")) row.setChatModel((String) body.get("chatModel"));
        if (body.containsKey("responsesModel")) row.setResponsesModel((String) body.get("responsesModel"));
        if (body.containsKey("apiKey")) row.setApiKey((String) body.get("apiKey"));
        if (body.containsKey("supportsChatCompletions"))
            row.setSupportsChatCompletions(Boolean.TRUE.equals(body.get("supportsChatCompletions")));
        if (body.containsKey("supportsResponses"))
            row.setSupportsResponses(Boolean.TRUE.equals(body.get("supportsResponses")));
        settingsRepository.save(row);
        return show(user);
    }

    private String previewKey(String key) {
        if (key == null || key.isEmpty()) return "";
        if (key.length() <= 8) return "*".repeat(key.length());
        return key.substring(0, 4) + "*".repeat(Math.max(key.length() - 8, 4)) + key.substring(key.length() - 4);
    }
}
