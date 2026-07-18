package nexus.campus.agent.memory.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import nexus.campus.agent.memory.dto.*;
import nexus.campus.agent.memory.entity.AgentMemory;
import nexus.campus.agent.memory.entity.MatchMemoryShare;
import nexus.campus.agent.memory.repository.AgentMemoryRepository;
import nexus.campus.agent.memory.repository.MatchMemoryShareRepository;
import nexus.campus.common.entity.User;
import nexus.campus.common.exception.ApiException;
import nexus.campus.help.entity.HelpMatch;
import nexus.campus.help.repository.HelpMatchRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.*;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
public class AgentMemoryService {
    public static final Set<String> KINDS = Set.of(
            "preference", "project", "environment", "resource", "relationship",
            "workflow", "constraint", "outcome", "other");
    public static final Set<String> STATUSES = Set.of("active", "archived");
    public static final Set<String> SOURCE_TYPES = Set.of(
            "user", "agent", "nexus_activity", "imported");
    public static final Set<String> SENSITIVITIES = Set.of(
            "normal", "sensitive", "restricted");
    public static final Set<String> SHARE_POLICIES = Set.of(
            "private", "ask_each_time");

    private static final Pattern CREDENTIAL_PATTERN = Pattern.compile(
            "(?i)\\b(api[_ -]?key|access[_ -]?token|password|secret)\\b\\s*[:=]\\s*\\S{6,}");

    private final AgentMemoryRepository memoryRepository;
    private final MatchMemoryShareRepository shareRepository;
    private final HelpMatchRepository matchRepository;
    private final ObjectMapper objectMapper;

    @Transactional(readOnly = true)
    public List<AgentMemoryResponse> list(
            Integer userId, String query, String kind, String status,
            List<String> tags, int limit, int offset) {
        limit = Math.min(Math.max(limit, 1), 50);
        offset = Math.max(offset, 0);
        String normalizedKind = blankToNull(kind);
        String normalizedStatus = blankToNull(status);
        Set<String> normalizedTags = normalizeTags(tags);

        return scoreAndFilter(userId, query, normalizedKind, normalizedStatus, normalizedTags)
                .stream()
                .skip(offset)
                .limit(limit)
                .map(scored -> toResponse(scored.memory(), scored.score()))
                .toList();
    }

    @Transactional(readOnly = true)
    public AgentMemoryResponse get(Integer userId, Integer memoryId) {
        return toResponse(ownedMemory(userId, memoryId), null);
    }

    @Transactional
    public List<AgentMemoryResponse> recall(Integer userId, AgentMemoryRecallRequest request) {
        int limit = request.getLimit() == null
                ? 10 : Math.min(Math.max(request.getLimit(), 1), 20);
        Set<String> kinds = normalizeAllowedList(request.getKinds(), KINDS);
        Set<String> tags = normalizeTags(request.getTags());

        var recalled = scoreAndFilter(userId, request.getQuery(), null, "active", tags)
                .stream()
                .filter(scored -> kinds.isEmpty() || kinds.contains(scored.memory().getKind()))
                .limit(limit)
                .toList();

        LocalDateTime now = LocalDateTime.now();
        if (!recalled.isEmpty()) {
            memoryRepository.touchRecall(
                    recalled.stream().map(scored -> scored.memory().getId()).toList(), now);
        }
        recalled.forEach(scored -> {
            AgentMemory memory = scored.memory();
            memory.setLastAccessedAt(now);
            memory.setAccessCount(memory.getAccessCount() + 1);
        });

        return recalled.stream()
                .map(scored -> toResponse(scored.memory(), scored.score()))
                .toList();
    }

    @Transactional
    public AgentMemoryResponse create(Integer userId, AgentMemoryWriteRequest request) {
        AgentMemory memory = new AgentMemory();
        User user = new User();
        user.setId(userId);
        memory.setUser(user);
        apply(memory, request, true);
        return toResponse(memoryRepository.save(memory), null);
    }

    @Transactional
    public AgentMemoryResponse update(
            Integer userId, Integer memoryId, AgentMemoryWriteRequest request) {
        AgentMemory memory = ownedMemory(userId, memoryId);
        apply(memory, request, false);
        return toResponse(memoryRepository.save(memory), null);
    }

    @Transactional
    public void delete(Integer userId, Integer memoryId) {
        AgentMemory memory = ownedMemory(userId, memoryId);
        shareRepository.deleteByMemory_Id(memoryId);
        memoryRepository.delete(memory);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> bootstrap(Integer userId) {
        List<ScoredMemory> active = scoreAndFilter(
                userId, null, null, "active", Set.of());
        List<AgentMemoryResponse> pinned = active.stream()
                .filter(scored -> scored.memory().isPinned())
                .limit(5)
                .map(scored -> toResponse(scored.memory(), null))
                .toList();
        return Map.of(
                "activeCount", active.size(),
                "pinned", pinned,
                "recallEndpoint", "/api/nexus/me/memories/recall",
                "manageEndpoint", "/api/nexus/me/memories",
                "policy", Map.of(
                        "defaultVisibility", "private",
                        "matchSharing", "explicit_snapshot_only",
                        "credentialsAllowed", false
                )
        );
    }

    @Transactional
    public List<MatchMemoryShareResponse> share(
            Integer actorId, Integer matchId, MatchMemoryShareRequest request) {
        HelpMatch match = acceptedMatchParticipant(matchId, actorId);
        List<Integer> ids = Optional.ofNullable(request.getMemoryIds()).orElse(List.of())
                .stream().distinct().limit(20).toList();
        if (ids.isEmpty()) {
            throw ApiException.badRequest("memoryIds", "Select at least one memory.");
        }

        User actor = new User();
        actor.setId(actorId);
        for (Integer memoryId : ids) {
            AgentMemory memory = ownedMemory(actorId, memoryId);
            if (!"active".equals(memory.getStatus()) || isExpired(memory)) {
                throw ApiException.badRequest("memoryIds", "Only active, unexpired memories can be shared.");
            }
            if (!"ask_each_time".equals(memory.getSharePolicy())) {
                throw ApiException.badRequest(
                        "sharePolicy",
                        "Set sharePolicy to ask_each_time before sharing this memory.");
            }
            if ("restricted".equals(memory.getSensitivity())) {
                throw ApiException.badRequest(
                        "sensitivity",
                        "Restricted memories cannot be shared into a match.");
            }

            MatchMemoryShare share = shareRepository
                    .findByMatch_IdAndMemory_Id(matchId, memoryId)
                    .orElseGet(MatchMemoryShare::new);
            share.setMatch(match);
            share.setMemory(memory);
            share.setOwner(memory.getUser());
            share.setSharedBy(actor);
            share.setSnapshotKind(memory.getKind());
            share.setSnapshotTitle(memory.getTitle());
            share.setSnapshotContent(memory.getContent());
            share.setSnapshotTags(memory.getTags());
            share.setSnapshotSensitivity(memory.getSensitivity());
            share.setCreatedAt(LocalDateTime.now());
            share.setRevokedAt(null);
            shareRepository.save(share);
        }
        return activeShares(matchId).stream().map(this::toShareResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<MatchMemoryShareResponse> sharedContext(Integer actorId, Integer matchId) {
        matchParticipant(matchId, actorId);
        return activeShares(matchId).stream().map(this::toShareResponse).toList();
    }

    @Transactional
    public MatchMemoryShareResponse revoke(Integer actorId, Integer matchId, Integer shareId) {
        matchParticipant(matchId, actorId);
        MatchMemoryShare share = shareRepository.findByIdAndMatch_Id(shareId, matchId)
                .orElseThrow(() -> ApiException.notFound("memory share", shareId));
        if (!share.getOwner().getId().equals(actorId)) {
            throw ApiException.forbidden();
        }
        share.setRevokedAt(LocalDateTime.now());
        return toShareResponse(shareRepository.save(share));
    }

    private List<ScoredMemory> scoreAndFilter(
            Integer userId, String query, String kind, String status, Set<String> requiredTags) {
        String normalizedQuery = Optional.ofNullable(query).orElse("").trim().toLowerCase(Locale.ROOT);
        List<String> terms = Arrays.stream(normalizedQuery.split("[^\\p{L}\\p{N}_-]+"))
                .filter(term -> term.length() > 1)
                .distinct()
                .toList();

        return memoryRepository.findByUser_IdOrderByPinnedDescImportanceDescUpdatedAtDesc(userId)
                .stream()
                .filter(memory -> kind == null || kind.equals(memory.getKind()))
                .filter(memory -> status == null || status.equals(memory.getStatus()))
                .filter(memory -> !"active".equals(memory.getStatus()) || !isExpired(memory))
                .filter(memory -> memory.getValidFrom() == null
                        || !memory.getValidFrom().isAfter(LocalDateTime.now()))
                .filter(memory -> requiredTags.isEmpty()
                        || parseTags(memory.getTags()).containsAll(requiredTags))
                .map(memory -> new ScoredMemory(memory, score(memory, normalizedQuery, terms)))
                .filter(scored -> normalizedQuery.isEmpty()
                        || scored.score() > rounded(baseScore(scored.memory())) + 0.01)
                .sorted(Comparator.comparingDouble(ScoredMemory::score).reversed()
                        .thenComparing(scored -> scored.memory().getUpdatedAt(),
                                Comparator.nullsLast(Comparator.reverseOrder())))
                .toList();
    }

    double score(AgentMemory memory, String normalizedQuery, List<String> terms) {
        double score = baseScore(memory);
        if (normalizedQuery.isEmpty()) return rounded(score);

        String title = memory.getTitle().toLowerCase(Locale.ROOT);
        String content = memory.getContent().toLowerCase(Locale.ROOT);
        Set<String> tags = parseTags(memory.getTags());

        if (title.contains(normalizedQuery)) score += 6;
        if (content.contains(normalizedQuery)) score += 3;
        for (String term : terms) {
            if (title.contains(term)) score += 2.5;
            if (content.contains(term)) score += 1.2;
            if (tags.stream().anyMatch(tag -> tag.contains(term))) score += 2;
            if (memory.getKind().contains(term)) score += 1;
        }
        return rounded(score);
    }

    private double baseScore(AgentMemory memory) {
        double score = memory.getImportance() * 0.5;
        if (memory.isPinned()) score += 2.5;
        if (memory.getUpdatedAt() != null) {
            long ageDays = Math.max(0, Duration.between(
                    memory.getUpdatedAt(), LocalDateTime.now()).toDays());
            score += 1.5 / (1 + ageDays / 30.0);
        }
        return score;
    }

    private void apply(AgentMemory memory, AgentMemoryWriteRequest request, boolean creating) {
        if (creating || request.getKind() != null) {
            memory.setKind(allowed(
                    "kind", request.getKind(), KINDS, creating ? "other" : memory.getKind()));
        }
        if (creating || request.getTitle() != null) {
            memory.setTitle(requiredText("title", request.getTitle(), 160));
        }
        if (creating || request.getContent() != null) {
            memory.setContent(requiredText("content", request.getContent(), 12000));
        }
        rejectCredentials(memory.getTitle());
        rejectCredentials(memory.getContent());

        if (request.getTags() != null) memory.setTags(encodeTags(request.getTags()));
        if (request.getStatus() != null) {
            memory.setStatus(allowed("status", request.getStatus(), STATUSES, memory.getStatus()));
        }
        if (request.getImportance() != null) {
            if (request.getImportance() < 1 || request.getImportance() > 5) {
                throw ApiException.badRequest("importance", "importance must be between 1 and 5.");
            }
            memory.setImportance(request.getImportance());
        }
        if (request.getPinned() != null) memory.setPinned(request.getPinned());
        if (request.getSourceType() != null || creating) {
            memory.setSourceType(allowed(
                    "sourceType", request.getSourceType(), SOURCE_TYPES,
                    creating ? "user" : memory.getSourceType()));
        }
        if (request.getSourceRef() != null) {
            memory.setSourceRef(optionalText(request.getSourceRef(), 255));
        }
        if (request.getSensitivity() != null || creating) {
            memory.setSensitivity(allowed(
                    "sensitivity", request.getSensitivity(), SENSITIVITIES,
                    creating ? "normal" : memory.getSensitivity()));
        }
        if (request.getSharePolicy() != null || creating) {
            memory.setSharePolicy(allowed(
                    "sharePolicy", request.getSharePolicy(), SHARE_POLICIES,
                    creating ? "private" : memory.getSharePolicy()));
        }
        if (request.getValidFrom() != null) memory.setValidFrom(request.getValidFrom());
        if (Boolean.TRUE.equals(request.getClearExpiresAt())
                && request.getExpiresAt() != null) {
            throw ApiException.badRequest(
                    "expiresAt", "expiresAt and clearExpiresAt cannot be set together.");
        }
        if (Boolean.TRUE.equals(request.getClearExpiresAt())) {
            memory.setExpiresAt(null);
        } else if (request.getExpiresAt() != null) {
            memory.setExpiresAt(request.getExpiresAt());
        }
        if (memory.getValidFrom() != null && memory.getExpiresAt() != null
                && !memory.getExpiresAt().isAfter(memory.getValidFrom())) {
            throw ApiException.badRequest("expiresAt", "expiresAt must be after validFrom.");
        }
    }

    private AgentMemory ownedMemory(Integer userId, Integer memoryId) {
        return memoryRepository.findByIdAndUser_Id(memoryId, userId)
                .orElseThrow(() -> ApiException.notFound("memory", memoryId));
    }

    private HelpMatch acceptedMatchParticipant(Integer matchId, Integer userId) {
        HelpMatch match = matchParticipant(matchId, userId);
        if (!"accepted".equals(match.getStatus())) {
            throw ApiException.badRequest(
                    "status", "Memory context can only be shared in an accepted match.");
        }
        return match;
    }

    private HelpMatch matchParticipant(Integer matchId, Integer userId) {
        HelpMatch match = matchRepository.findById(matchId)
                .orElseThrow(() -> ApiException.notFound("match", matchId));
        boolean requester = match.getHelpRequest().getRequester().getId().equals(userId);
        boolean helper = match.getHelper().getId().equals(userId);
        if (!requester && !helper) throw ApiException.forbidden();
        return match;
    }

    private List<MatchMemoryShare> activeShares(Integer matchId) {
        return shareRepository.findByMatch_IdAndRevokedAtIsNullOrderByCreatedAtAsc(matchId);
    }

    private AgentMemoryResponse toResponse(AgentMemory memory, Double score) {
        return AgentMemoryResponse.builder()
                .id(memory.getId())
                .kind(memory.getKind())
                .title(memory.getTitle())
                .content(memory.getContent())
                .tags(new ArrayList<>(parseTags(memory.getTags())))
                .status(memory.getStatus())
                .importance(memory.getImportance())
                .pinned(memory.isPinned())
                .sourceType(memory.getSourceType())
                .sourceRef(memory.getSourceRef())
                .sensitivity(memory.getSensitivity())
                .sharePolicy(memory.getSharePolicy())
                .validFrom(memory.getValidFrom())
                .expiresAt(memory.getExpiresAt())
                .lastAccessedAt(memory.getLastAccessedAt())
                .accessCount(memory.getAccessCount())
                .createdAt(memory.getCreatedAt())
                .updatedAt(memory.getUpdatedAt())
                .retrievalScore(score)
                .build();
    }

    private MatchMemoryShareResponse toShareResponse(MatchMemoryShare share) {
        return MatchMemoryShareResponse.builder()
                .id(share.getId())
                .matchId(share.getMatch().getId())
                .memoryId(share.getMemory().getId())
                .ownerUserId(share.getOwner().getId())
                .sharedByUserId(share.getSharedBy().getId())
                .kind(share.getSnapshotKind())
                .title(share.getSnapshotTitle())
                .content(share.getSnapshotContent())
                .tags(new ArrayList<>(parseTags(share.getSnapshotTags())))
                .sensitivity(share.getSnapshotSensitivity())
                .createdAt(share.getCreatedAt())
                .revokedAt(share.getRevokedAt())
                .build();
    }

    private String encodeTags(List<String> values) {
        try {
            return objectMapper.writeValueAsString(normalizeTags(values));
        } catch (Exception e) {
            throw ApiException.badRequest("tags", "tags could not be encoded.");
        }
    }

    private Set<String> parseTags(String value) {
        if (value == null || value.isBlank()) return new LinkedHashSet<>();
        try {
            return new LinkedHashSet<>(objectMapper.readValue(
                    value, new TypeReference<List<String>>() {}));
        } catch (Exception ignored) {
            return new LinkedHashSet<>();
        }
    }

    private Set<String> normalizeTags(List<String> values) {
        if (values == null) return Set.of();
        var tags = new LinkedHashSet<String>();
        for (String value : values) {
            if (value == null) continue;
            String tag = value.trim().toLowerCase(Locale.ROOT)
                    .replaceAll("[^\\p{L}\\p{N}_-]+", "-")
                    .replaceAll("^[-_]+|[-_]+$", "");
            if (!tag.isBlank()) tags.add(tag.length() > 80 ? tag.substring(0, 80) : tag);
            if (tags.size() > 20) {
                throw ApiException.badRequest("tags", "A memory can have at most 20 tags.");
            }
        }
        return tags;
    }

    private Set<String> normalizeAllowedList(List<String> values, Set<String> allowed) {
        if (values == null) return Set.of();
        var normalized = new LinkedHashSet<String>();
        for (String value : values) {
            if (!allowed.contains(value)) {
                throw ApiException.badRequest("kinds", "Unsupported memory kind: " + value);
            }
            normalized.add(value);
        }
        return normalized;
    }

    private String allowed(
            String field, String value, Set<String> values, String defaultValue) {
        String normalized = blankToNull(value);
        if (normalized == null) return defaultValue;
        normalized = normalized.toLowerCase(Locale.ROOT);
        if (!values.contains(normalized)) {
            throw ApiException.badRequest(
                    field, field + " must be one of: " + String.join(", ", values) + ".");
        }
        return normalized;
    }

    private String requiredText(String field, String value, int max) {
        String normalized = blankToNull(value);
        if (normalized == null) throw ApiException.badRequest(field, field + " is required.");
        if (normalized.length() > max) {
            throw ApiException.badRequest(field, field + " is too long.");
        }
        return normalized;
    }

    private String optionalText(String value, int max) {
        String normalized = blankToNull(value);
        if (normalized == null) return null;
        return normalized.length() > max ? normalized.substring(0, max) : normalized;
    }

    private void rejectCredentials(String value) {
        if (value != null && CREDENTIAL_PATTERN.matcher(value).find()) {
            throw ApiException.badRequest(
                    "content",
                    "Do not store passwords, API keys, tokens, or secrets in Nexus memory.");
        }
    }

    private boolean isExpired(AgentMemory memory) {
        return memory.getExpiresAt() != null
                && !memory.getExpiresAt().isAfter(LocalDateTime.now());
    }

    private String blankToNull(String value) {
        if (value == null || value.trim().isEmpty()) return null;
        return value.trim();
    }

    private double rounded(double score) {
        return Math.round(score * 100.0) / 100.0;
    }

    private record ScoredMemory(AgentMemory memory, double score) {}
}
