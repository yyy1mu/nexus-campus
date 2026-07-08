package nexus.campus.common.logging;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import nexus.campus.agent.entity.AgentActionLog;
import nexus.campus.agent.repository.AgentActionLogRepository;
import nexus.campus.common.entity.User;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ActionLogService {

    private final AgentActionLogRepository logRepository;
    private final ObjectMapper objectMapper;

    private static final Pattern SECRET_KEY_PATTERN =
            Pattern.compile("api.?key|token|secret|password|authorization|cookie|csrf", Pattern.CASE_INSENSITIVE);

    public AgentActionLog log(User actor, String actionType, String targetType,
                               Integer targetId, Map<String, Object> inputSummary,
                               Map<String, Object> outputSummary, String ipAddress,
                               boolean userConfirmed) {
        var log = new AgentActionLog();
        log.setUser(actor);
        log.setActionType(actionType);
        log.setTargetType(targetType);
        log.setTargetId(targetId);
        log.setStatus("succeeded");
        log.setUserConfirmed(userConfirmed);
        log.setInputSummary(encodeSummary(inputSummary));
        log.setOutputSummary(encodeSummary(outputSummary));
        log.setIpAddress(truncate(ipAddress, 45));
        return logRepository.save(log);
    }

    public int length(String value) {
        return value == null ? 0 : value.length();
    }

    public String encodeSummary(Map<String, Object> summary) {
        var sanitized = sanitize(summary);
        if (sanitized.isEmpty()) return null;
        try {
            String json = objectMapper.writeValueAsString(sanitized);
            if (json.length() <= 4000) return json;
            return objectMapper.writeValueAsString(Map.of(
                    "truncated", true,
                    "summaryKeys", sanitized.keySet().stream().map(Object::toString).collect(Collectors.toList())
            ));
        } catch (JsonProcessingException e) {
            return null;
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> sanitize(Object value) {
        if (value instanceof Map<?, ?> map) {
            var clean = new LinkedHashMap<String, Object>();
            map.forEach((k, v) -> {
                String key = k.toString();
                if (isSecretKey(key)) {
                    clean.put(key, "[redacted]");
                } else {
                    clean.put(key, sanitize(v));
                }
            });
            return clean;
        }
        if (value instanceof String s) {
            return Map.of("value", truncate(s, 300));
        }
        if (value instanceof Boolean || value instanceof Number || value == null) {
            return value == null ? Map.of() : Map.of("value", value);
        }
        return Map.of("value", value.toString());
    }

    private boolean isSecretKey(String key) {
        return SECRET_KEY_PATTERN.matcher(key).find();
    }

    private String truncate(String value, int max) {
        if (value == null || value.trim().isEmpty()) return null;
        value = value.trim();
        if (value.length() <= max) return value;
        return value.substring(0, max - 12) + "...[truncated]";
    }
}
