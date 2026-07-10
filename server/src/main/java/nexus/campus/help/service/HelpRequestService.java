package nexus.campus.help.service;

import lombok.RequiredArgsConstructor;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import nexus.campus.help.entity.HelpRequest;
import nexus.campus.help.repository.HelpRequestRepository;
import nexus.campus.common.validation.PayloadValidator;
import nexus.campus.common.exception.ApiException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class HelpRequestService {

    private final HelpRequestRepository helpRequestRepository;
    private final PayloadValidator v;
    private final ObjectMapper objectMapper;

    @Transactional
    public HelpRequest create(Integer requesterId, Integer discussionId, Map<String, Object> payload) {
        var req = new HelpRequest();
        req.setRequester(new nexus.campus.common.entity.User());
        req.getRequester().setId(requesterId);

        req.setDiscussionId(discussionId);
        req.setCategoryLabel(v.string(payload, "categoryLabel", 80, false));
        req.setNeededLabels(encodeStringList(payload, "neededLabels"));
        req.setSummary(v.string(payload, "summary", 2000, true));
        req.setUrgency(v.oneOf(payload, "urgency",
                java.util.Set.of("normal", "urgent", "relaxed"), "normal"));
        req.setLocationHint(v.string(payload, "locationHint", 255, false));
        req.setMeetingSafetyState(v.oneOf(payload, "meetingSafetyState",
                java.util.Set.of("not_arranged", "public_place_suggested", "public_place_confirmed"),
                "not_arranged"));
        req.setAgentContext(v.string(payload, "agentContext", 4000, false));
        req.setStatus("open");

        return helpRequestRepository.save(req);
    }

    @Transactional
    public HelpRequest update(Integer id, Integer actorId, Map<String, Object> payload) {
        var req = helpRequestRepository.findById(id).orElseThrow();
        // Authorization checked by controller

        if (payload.containsKey("status")) {
            req.setStatus(v.oneOf(payload, "status",
                    java.util.Set.of("open", "matching", "matched", "closed", "cancelled"),
                    req.getStatus()));
        }
        if (payload.containsKey("meetingSafetyState")) {
            req.setMeetingSafetyState(v.oneOf(payload, "meetingSafetyState",
                    java.util.Set.of("not_arranged", "public_place_suggested", "public_place_confirmed"),
                    req.getMeetingSafetyState()));
        }
        if (payload.containsKey("locationHint")) {
            req.setLocationHint(v.string(payload, "locationHint", 255, false));
        }
        if (payload.containsKey("summary")) {
            req.setSummary(v.string(payload, "summary", 2000, true));
        }
        if (payload.containsKey("neededLabels")) {
            req.setNeededLabels(encodeStringList(payload, "neededLabels"));
        }
        if (payload.containsKey("agentContext")) {
            req.setAgentContext(v.string(payload, "agentContext", 4000, false));
        }

        if (java.util.Set.of("closed", "cancelled").contains(req.getStatus()) && req.getClosedAt() == null) {
            req.setClosedAt(LocalDateTime.now());
        } else if (!java.util.Set.of("closed", "cancelled").contains(req.getStatus())) {
            req.setClosedAt(null);
        }

        return helpRequestRepository.save(req);
    }

    private String encodeStringList(Map<String, Object> attrs, String key) {
        var list = v.stringList(attrs, key, 12);
        if (list.isEmpty()) return null;
        try {
            return objectMapper.writeValueAsString(list);
        } catch (JsonProcessingException e) {
            return null;
        }
    }
}
