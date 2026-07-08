package nexus.campus.agent.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.agent.dto.AgentProfileResponse;
import nexus.campus.agent.dto.AgentProfileUpdateRequest;
import nexus.campus.agent.entity.AgentProfile;
import nexus.campus.agent.service.AgentProfileService;
import nexus.campus.common.entity.User;
import nexus.campus.common.exception.ApiException;
import nexus.campus.common.response.ApiResponse;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class AgentProfileController {

    private final AgentProfileService profileService;

    @GetMapping("/me/agent-profile")
    public ApiResponse<AgentProfileResponse> show(@AuthenticationPrincipal User user) {
        return ApiResponse.ok(toResponse(profileService.getOrCreate(user.getId())));
    }

    @PatchMapping("/me/agent-profile")
    public ApiResponse<AgentProfileResponse> update(
            @AuthenticationPrincipal User user,
            @RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        var attrs = (Map<String, Object>) ((Map<String, Object>) body.get("data")).getOrDefault("attributes", body);
        if (!Boolean.TRUE.equals(attrs.get("userConfirmed")))
            throw ApiException.badRequest("userConfirmed", "User confirmation required.");

        var profile = profileService.update(user.getId(), attrs);
        return ApiResponse.ok(toResponse(profile));
    }

    private AgentProfileResponse toResponse(AgentProfile p) {
        return AgentProfileResponse.builder()
                .userId(p.getUserId())
                .agentName(p.getAgentName())
                .agentAvatarUrl(p.getAgentAvatarUrl())
                .soulMd(p.getSoulMd())
                .permissions(Map.of(
                    "allowAgentPosting", p.isAllowAgentPosting(),
                    "allowAgentReplying", p.isAllowAgentReplying(),
                    "allowAgentMatching", p.isAllowAgentMatching(),
                    "allowLocationMatching", p.isAllowLocationMatching()
                ))
                .build();
    }
}
