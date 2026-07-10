package nexus.campus.common.validation;

import nexus.campus.common.exception.ApiException;
import org.springframework.stereotype.Component;

import java.util.*;
import java.util.stream.Collectors;

@Component
public class PayloadValidator {

    public String string(Map<String, Object> payload, String key, int max, boolean required) {
        Object value = payload.get(key);
        if (value == null || value.toString().trim().isEmpty()) {
            if (required) throw ApiException.badRequest(key, key + " is required.");
            return null;
        }
        String str = value.toString().trim();
        if (str.length() > max) throw ApiException.badRequest(key, key + " is too long.");
        return str;
    }

    public String oneOf(Map<String, Object> payload, String key, Set<String> allowed, String defaultValue) {
        String value = payload.containsKey(key)
                ? Objects.toString(payload.get(key), defaultValue) : defaultValue;
        if (!allowed.contains(value))
            throw ApiException.badRequest(key, key + " must be one of: " + String.join(", ", allowed) + ".");
        return value;
    }

    @SuppressWarnings("unchecked")
    public List<String> stringList(Map<String, Object> payload, String key, int maxItems) {
        Object value = payload.get(key);
        if (value == null || (value instanceof String s && s.isEmpty())) return List.of();
        List<String> raw;
        if (value instanceof String s) raw = Arrays.asList(s.split("[,，\\s]+"));
        else if (value instanceof List<?> list) raw = list.stream().map(Object::toString).collect(Collectors.toList());
        else throw ApiException.badRequest(key, key + " must be an array of labels.");
        Set<String> items = new LinkedHashSet<>();
        for (String item : raw) { String label = label(item); if (!label.isEmpty()) items.add(label); }
        List<String> result = new ArrayList<>(items);
        if (result.size() > maxItems) throw ApiException.badRequest(key, key + " has too many labels.");
        return result;
    }

    public String label(String value) {
        String s = value.trim().toLowerCase().replaceAll("[^\\p{L}\\p{N}_-]+", "-")
                .replaceAll("^[-_]+|[-_]+$", "");
        return s.length() > 80 ? s.substring(0, 80) : s;
    }
}
