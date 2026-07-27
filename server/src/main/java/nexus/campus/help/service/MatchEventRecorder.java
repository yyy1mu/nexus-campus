package nexus.campus.help.service;

import lombok.RequiredArgsConstructor;
import nexus.campus.common.entity.User;
import nexus.campus.help.entity.HelpMatch;
import nexus.campus.help.entity.MatchEvent;
import nexus.campus.help.repository.MatchEventRepository;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class MatchEventRecorder {

    private final MatchEventRepository eventRepository;

    public MatchEvent record(HelpMatch match, Integer actorId, String actorRole,
                             String eventType, String refType, Integer refId, String summary) {
        var event = new MatchEvent();
        event.setMatch(match);
        if (actorId != null) {
            var actor = new User();
            actor.setId(actorId);
            event.setActor(actor);
        }
        event.setActorRole(actorRole);
        event.setEventType(eventType);
        event.setRefType(refType);
        event.setRefId(refId);
        event.setSummary(summary != null && summary.length() > 500
                ? summary.substring(0, 497) + "..." : summary);
        return eventRepository.save(event);
    }
}
