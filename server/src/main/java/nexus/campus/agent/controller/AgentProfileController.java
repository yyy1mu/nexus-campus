package nexus.campus.agent.controller;

import lombok.RequiredArgsConstructor;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import nexus.campus.agent.dto.AgentProfileResponse;
import nexus.campus.agent.entity.AgentProfile;
import nexus.campus.agent.service.AgentProfileService;
import nexus.campus.common.entity.User;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.security.authorization.AgentWriteGuard;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class AgentProfileController {

    private final AgentProfileService profileService;
    private final AgentWriteGuard guard;
    private final ObjectMapper objectMapper;

    @GetMapping("/me/agent-profile")
    public ApiResponse<AgentProfileResponse> show(@AuthenticationPrincipal User user) {
        return ApiResponse.ok(toResponse(profileService.getOrCreate(user.getId())));
    }

    @PatchMapping("/me/agent-profile")
    public ApiResponse<AgentProfileResponse> update(
            @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        guard.requireConfirmedUser(user, body);
        var profile = profileService.update(user.getId(), body);
        return ApiResponse.ok(toResponse(profile));
    }

    private AgentProfileResponse toResponse(AgentProfile p) {
        return AgentProfileResponse.builder()
                .userId(p.getUserId())
                .agentName(p.getAgentName())
                .agentAvatarUrl(p.getAgentAvatarUrl())
                .soulMd(p.getSoulMd())
                .interestTags(parseList(p.getInterestTags()))
                .skillTags(parseList(p.getSkillTags()))
                .helpTags(parseList(p.getHelpTags()))
                .matchPreferences(parseMap(p.getMatchPreferences()))
                .permissions(Map.of(
                    "allowAgentPosting", p.isAllowAgentPosting(),
                    "allowAgentReplying", p.isAllowAgentReplying(),
                    "allowAgentMatching", p.isAllowAgentMatching(),
                    "allowLocationMatching", p.isAllowLocationMatching()
                ))
                .build();
    }

    private List<String> parseList(String value) {
        if (value == null || value.isBlank()) return List.of();
        try {
            return objectMapper.readValue(value, new TypeReference<List<String>>() {});
        } catch (Exception ignored) {
            return List.of();
        }
    }

    private Map<String, Object> parseMap(String value) {
        if (value == null || value.isBlank()) return Map.of();
        try {
            return objectMapper.readValue(value, new TypeReference<Map<String, Object>>() {});
        } catch (Exception ignored) {
            return Map.of();
        }
    }
}
