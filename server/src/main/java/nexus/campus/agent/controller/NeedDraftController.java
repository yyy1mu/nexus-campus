package nexus.campus.agent.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.agent.service.AgentNextActionEnricher;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class NeedDraftController {

    private final AgentNextActionEnricher enricher;

    @PostMapping("/need-drafts")
    public ApiResponse<Map<String, Object>> draft(@RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        var attrs = (Map<String, Object>) ((Map<String, Object>) body.get("data"))
                .getOrDefault("attributes", body);
        String rawNeed = (String) attrs.getOrDefault("rawUserNeed", "");
        String intent = (String) attrs.getOrDefault("intent", "physical_help_request");

        var keywords = extractKeywords(rawNeed);
        var suggestedLabels = suggestLabels(rawNeed);

        var result = new LinkedHashMap<String, Object>();
        result.put("rawUserNeed", rawNeed);
        result.put("intent", intent);
        result.put("title", "Help: " + (rawNeed.length() > 60 ? rawNeed.substring(0, 60) + "..." : rawNeed));
        result.put("summary", rawNeed);
        result.put("neededLabels", suggestedLabels);
        result.put("urgency", detectUrgency(rawNeed));
        result.put("suggestedSearchQueries", keywords);

        result.put("labelReuse", Map.of(
                "policy", "Search for existing labels before creating new ones.",
                "suggestedQueries", suggestedLabels.stream()
                        .map(l -> Map.of("label", l, "endpoint", "/api/nexus/capability-labels",
                                "query", Map.of("inname", l, "sort", "popular")))
                        .toList()
        ));

        result.put("discoveryPlan", Map.of(
                "steps", List.of(
                        Map.of("name", "find_existing_labels", "endpoint", "/api/nexus/capability-labels",
                                "query", Map.of("inname", keywords.get(0), "sort", "popular")),
                        Map.of("name", "search_open_requests", "endpoint", "/api/nexus/help-requests",
                                "query", Map.of("filter[status]", "open")),
                        Map.of("name", "preflight_create", "endpoint", "/api/nexus/agent-preflight",
                                "body", Map.of("action", "help_request.create"))
                )
        ));

        result.put("nextAction", enricher.enrich("help_request.create", "Create a public help request after user confirms."));
        result.put("safetyNotes", "Offline coordination should prefer public, safe, easy-to-leave places.");

        return ApiResponse.ok(result);
    }

    private List<String> extractKeywords(String text) {
        var words = new ArrayList<String>();
        String lower = text.toLowerCase();
        for (String kw : List.of("math", "tutoring", "repair", "bike", "laptop", "printer",
                "moving", "help", "study", "design", "photo", "code", "bug")) {
            if (lower.contains(kw)) words.add(kw);
        }
        return words.isEmpty() ? List.of("help") : words;
    }

    private List<String> suggestLabels(String text) {
        var labels = new ArrayList<String>();
        String lower = text.toLowerCase();
        var mapping = Map.of(
                "tutoring", "math|study|tutor|learn|help with class|homework",
                "computer-repair", "laptop|computer|pc|screen|keyboard|software|bug",
                "bike-repair", "bike|bicycle|flat tire|chain",
                "moving-help", "moving|carry|lift|heavy|furniture",
                "printer-help", "printer|print|paper|ink",
                "photography", "photo|camera|picture|film",
                "campus-process", "register|form|office|admin"
        );
        for (var entry : mapping.entrySet()) {
            for (String kw : entry.getValue().split("\\|")) {
                if (lower.contains(kw.trim())) { labels.add(entry.getKey()); break; }
            }
        }
        return labels.isEmpty() ? List.of("general-help") : labels;
    }

    private String detectUrgency(String text) {
        String lower = text.toLowerCase();
        if (lower.contains("urgent") || lower.contains("asap") || lower.contains("紧急") || lower.contains("immediately"))
            return "urgent";
        return "normal";
    }
}
