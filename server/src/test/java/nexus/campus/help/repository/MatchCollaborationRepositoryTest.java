package nexus.campus.help.repository;

import nexus.campus.common.entity.User;
import nexus.campus.help.entity.HelpMatch;
import nexus.campus.help.entity.HelpRequest;
import nexus.campus.help.entity.MatchEvent;
import nexus.campus.help.entity.MatchTask;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;

@DataJpaTest
class MatchCollaborationRepositoryTest {

    @Autowired
    private TestEntityManager entityManager;

    @Autowired
    private MatchEventRepository eventRepository;

    @Autowired
    private MatchTaskRepository taskRepository;

    @Test
    void eventsAfterIdReturnOnlyNewerEventsInOrder() {
        HelpMatch match = persistedMatch("events");
        MatchEvent first = event(match, "task.created", "任务已创建");
        entityManager.persist(first);
        MatchEvent second = event(match, "decision.opened", "等待求助方决策");
        entityManager.persist(second);
        MatchEvent third = event(match, "deliverable.submitted", "交付物已提交");
        entityManager.persistAndFlush(third);

        var newer = eventRepository.findByMatchIdAndIdGreaterThanOrderByIdAsc(
                match.getId(), first.getId());

        assertEquals(2, newer.size());
        assertEquals(second.getId(), newer.get(0).getId());
        assertEquals(third.getId(), newer.get(1).getId());
    }

    @Test
    void duplicateClientRequestIdViolatesTaskConstraint() {
        HelpMatch match = persistedMatch("tasks");
        MatchTask original = task(match, "拉取样例切片", "client-req-1");
        entityManager.persistAndFlush(original);

        MatchTask duplicate = task(match, "重复请求", "client-req-1");
        assertThrows(Exception.class, () -> {
            taskRepository.saveAndFlush(duplicate);
        });
    }

    private HelpMatch persistedMatch(String tag) {
        User requester = user("requester-" + tag);
        User helper = user("helper-" + tag);
        entityManager.persist(requester);
        entityManager.persist(helper);

        HelpRequest request = new HelpRequest();
        request.setRequester(requester);
        request.setSummary("Need a usable remote-sensing dataset");
        entityManager.persist(request);

        HelpMatch match = new HelpMatch();
        match.setHelpRequest(request);
        match.setHelper(helper);
        match.setStatus("accepted");
        entityManager.persist(match);
        return match;
    }

    private User user(String name) {
        User user = new User();
        user.setUsername(name);
        user.setEmail(name + "@example.test");
        user.setPassword("test-password");
        user.setJoinedAt(Instant.now());
        return user;
    }

    private MatchEvent event(HelpMatch match, String type, String summary) {
        MatchEvent event = new MatchEvent();
        event.setMatch(match);
        event.setEventType(type);
        event.setSummary(summary);
        return event;
    }

    private MatchTask task(HelpMatch match, String title, String clientRequestId) {
        MatchTask task = new MatchTask();
        task.setMatch(match);
        task.setCreatedBy(match.getHelper());
        task.setOwnerRole("helper");
        task.setTitle(title);
        task.setClientRequestId(clientRequestId);
        return task;
    }
}
