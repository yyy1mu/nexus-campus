package nexus.campus.help.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import nexus.campus.agent.service.AgentNextActionEnricher;
import nexus.campus.common.entity.User;
import nexus.campus.common.exception.ApiException;
import nexus.campus.common.validation.PayloadValidator;
import nexus.campus.help.entity.*;
import nexus.campus.help.repository.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class MatchCollaborationServiceTest {

    private static final int REQUESTER_ID = 4;
    private static final int HELPER_ID = 5;
    private static final int OUTSIDER_ID = 99;
    private static final int MATCH_ID = 12;

    private HelpMatchRepository matchRepository;
    private MatchTaskRepository taskRepository;
    private MatchDecisionRepository decisionRepository;
    private MatchDeliverableRepository deliverableRepository;
    private MatchEventRepository eventRepository;
    private MatchEventRecorder events;
    private MatchCollaborationService service;
    private HelpMatch match;

    @BeforeEach
    void setUp() {
        matchRepository = mock(HelpMatchRepository.class);
        taskRepository = mock(MatchTaskRepository.class);
        decisionRepository = mock(MatchDecisionRepository.class);
        deliverableRepository = mock(MatchDeliverableRepository.class);
        eventRepository = mock(MatchEventRepository.class);
        events = mock(MatchEventRecorder.class);
        service = new MatchCollaborationService(
                matchRepository, taskRepository, decisionRepository,
                deliverableRepository, eventRepository, events,
                new AgentNextActionEnricher(), new PayloadValidator(), new ObjectMapper());

        var request = new HelpRequest();
        request.setRequester(user(REQUESTER_ID));
        request.setSummary("Need a usable remote-sensing dataset");
        match = new HelpMatch();
        match.setId(MATCH_ID);
        match.setHelpRequest(request);
        match.setHelper(user(HELPER_ID));
        match.setStatus("accepted");
        when(matchRepository.findById(MATCH_ID)).thenReturn(Optional.of(match));
    }

    // ── Isolation ──

    @Test
    void nonParticipantCannotReadWorkspace() {
        ApiException e = assertThrows(ApiException.class,
                () -> service.workspace(MATCH_ID, OUTSIDER_ID));
        assertEquals(403, e.getStatus());
    }

    @Test
    void nonParticipantCannotCreateTask() {
        ApiException e = assertThrows(ApiException.class,
                () -> service.createTask(MATCH_ID, OUTSIDER_ID,
                        Map.of("title", "Steal the plan")));
        assertEquals(403, e.getStatus());
        verify(taskRepository, never()).save(any());
    }

    @Test
    void workspaceRequiresAcceptedMatchForWrites() {
        match.setStatus("offered");
        ApiException e = assertThrows(ApiException.class,
                () -> service.createTask(MATCH_ID, HELPER_ID, Map.of("title", "Too early")));
        assertEquals(400, e.getStatus());
        verify(taskRepository, never()).save(any());
    }

    // ── Pause control ──

    @Test
    void pausedWorkspaceRejectsNewWork() {
        match.setCollabState("paused");
        ApiException e = assertThrows(ApiException.class,
                () -> service.createTask(MATCH_ID, HELPER_ID, Map.of("title", "Push more work")));
        assertEquals(400, e.getStatus());
        verify(taskRepository, never()).save(any());
    }

    @Test
    void pausedWorkspaceStillAllowsHumanDecision() {
        match.setCollabState("paused");
        var decision = openDecision();
        when(decisionRepository.findByIdAndMatchId(31, MATCH_ID)).thenReturn(Optional.of(decision));
        when(decisionRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        var result = service.resolveDecision(MATCH_ID, 31, REQUESTER_ID,
                Map.of("action", "decide", "optionKey", "http"));

        assertEquals("decided", result.get("status"));
    }

    // ── Idempotency ──

    @Test
    void taskCreateReplayReturnsExistingRow() {
        var existing = new MatchTask();
        existing.setId(21);
        existing.setMatch(match);
        existing.setCreatedBy(user(HELPER_ID));
        existing.setOwnerRole("helper");
        existing.setTitle("Verify checksum");
        existing.setClientRequestId("req-1");
        when(taskRepository.findByMatchIdAndClientRequestId(MATCH_ID, "req-1"))
                .thenReturn(Optional.of(existing));

        var result = service.createTask(MATCH_ID, HELPER_ID,
                Map.of("title", "Verify checksum", "clientRequestId", "req-1"));

        assertEquals(21, result.get("id"));
        verify(taskRepository, never()).save(any());
        verify(events, never()).record(any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void deliverableSubmitReplayReturnsExistingRow() {
        var existing = new MatchDeliverable();
        existing.setId(41);
        existing.setMatch(match);
        existing.setSubmittedBy(user(HELPER_ID));
        existing.setSubmitterRole("helper");
        existing.setTitle("Dataset v1");
        when(deliverableRepository.findByMatchIdAndClientRequestId(MATCH_ID, "deliv-1"))
                .thenReturn(Optional.of(existing));

        var result = service.submitDeliverable(MATCH_ID, HELPER_ID,
                Map.of("title", "Dataset v1", "clientRequestId", "deliv-1"));

        assertEquals(41, result.get("id"));
        verify(deliverableRepository, never()).save(any());
    }

    // ── Baton enforcement ──

    @Test
    void batonWithCounterpartBlocksNewWork() {
        match.setBatonRole("requester");

        ApiException task = assertThrows(ApiException.class,
                () -> service.createTask(MATCH_ID, HELPER_ID, Map.of("title", "越过接力棒")));
        assertEquals(400, task.getStatus());

        ApiException deliverable = assertThrows(ApiException.class,
                () -> service.submitDeliverable(MATCH_ID, HELPER_ID, Map.of("title", "越过接力棒交付")));
        assertEquals(400, deliverable.getStatus());
        verify(taskRepository, never()).save(any());
        verify(deliverableRepository, never()).save(any());
    }

    @Test
    void batonHolderCanCreateWork() {
        match.setBatonRole("helper");
        when(taskRepository.countByMatchId(MATCH_ID)).thenReturn(0L);
        when(taskRepository.save(any())).thenAnswer(i -> {
            MatchTask t = i.getArgument(0);
            t.setId(77);
            return t;
        });

        var result = service.createTask(MATCH_ID, HELPER_ID, Map.of("title", "持棒方推进"));

        assertEquals(77, result.get("id"));
    }

    // ── Task owner boundary ──

    @Test
    void nonOwnerCannotAdvanceTask() {
        var task = new MatchTask();
        task.setId(21);
        task.setMatch(match);
        task.setCreatedBy(user(HELPER_ID));
        task.setOwnerRole("helper");
        task.setTitle("准备切片");
        task.setStatus("todo");
        when(taskRepository.findByIdAndMatchId(21, MATCH_ID)).thenReturn(Optional.of(task));

        ApiException e = assertThrows(ApiException.class,
                () -> service.updateTask(MATCH_ID, 21, REQUESTER_ID,
                        Map.of("status", "done")));

        assertEquals(403, e.getStatus());
        assertEquals("todo", task.getStatus());
    }

    @Test
    void eitherSideCanReassignTaskOwner() {
        var task = new MatchTask();
        task.setId(21);
        task.setMatch(match);
        task.setCreatedBy(user(HELPER_ID));
        task.setOwnerRole("helper");
        task.setTitle("抽样验证");
        task.setStatus("todo");
        when(taskRepository.findByIdAndMatchId(21, MATCH_ID)).thenReturn(Optional.of(task));
        when(taskRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        var result = service.updateTask(MATCH_ID, 21, REQUESTER_ID,
                Map.of("ownerRole", "requester"));

        assertEquals("requester", result.get("ownerRole"));
    }

    // ── Decisions ──

    @Test
    void decisionCannotBeAssignedToOwnSide() {
        ApiException e = assertThrows(ApiException.class,
                () -> service.openDecision(MATCH_ID, HELPER_ID, Map.of(
                        "title", "自问自答",
                        "assignedRole", "helper",
                        "options", List.of(
                                Map.of("key", "a", "label", "A"),
                                Map.of("key", "b", "label", "B")))));

        assertEquals(400, e.getStatus());
        verify(decisionRepository, never()).save(any());
    }

    @Test
    void onlyRaiserCanCancelDecision() {
        var decision = openDecision();
        when(decisionRepository.findByIdAndMatchId(31, MATCH_ID)).thenReturn(Optional.of(decision));

        ApiException e = assertThrows(ApiException.class,
                () -> service.resolveDecision(MATCH_ID, 31, REQUESTER_ID,
                        Map.of("action", "cancel")));
        assertEquals(403, e.getStatus());

        when(decisionRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        var cancelled = service.resolveDecision(MATCH_ID, 31, HELPER_ID,
                Map.of("action", "cancel"));
        assertEquals("cancelled", cancelled.get("status"));
    }

    @Test
    void onlyAssignedRoleCanDecide() {
        var decision = openDecision();
        when(decisionRepository.findByIdAndMatchId(31, MATCH_ID)).thenReturn(Optional.of(decision));

        ApiException e = assertThrows(ApiException.class,
                () -> service.resolveDecision(MATCH_ID, 31, HELPER_ID,
                        Map.of("action", "decide", "optionKey", "http")));
        assertEquals(403, e.getStatus());
        verify(decisionRepository, never()).save(any());
    }

    @Test
    void decidingTwiceWithSameOptionIsIdempotent() {
        var decision = openDecision();
        decision.setStatus("decided");
        decision.setDecidedOptionKey("http");
        when(decisionRepository.findByIdAndMatchId(31, MATCH_ID)).thenReturn(Optional.of(decision));

        var result = service.resolveDecision(MATCH_ID, 31, REQUESTER_ID,
                Map.of("action", "decide", "optionKey", "http"));

        assertEquals("decided", result.get("status"));
        assertEquals("http", result.get("decidedOptionKey"));
        verify(decisionRepository, never()).save(any());
    }

    @Test
    void decidingTwiceWithDifferentOptionFails() {
        var decision = openDecision();
        decision.setStatus("decided");
        decision.setDecidedOptionKey("http");
        when(decisionRepository.findByIdAndMatchId(31, MATCH_ID)).thenReturn(Optional.of(decision));

        ApiException e = assertThrows(ApiException.class,
                () -> service.resolveDecision(MATCH_ID, 31, REQUESTER_ID,
                        Map.of("action", "decide", "optionKey", "usb")));
        assertEquals(400, e.getStatus());
    }

    @Test
    void decisionOptionKeyMustMatchOfferedOptions() {
        var decision = openDecision();
        when(decisionRepository.findByIdAndMatchId(31, MATCH_ID)).thenReturn(Optional.of(decision));

        ApiException e = assertThrows(ApiException.class,
                () -> service.resolveDecision(MATCH_ID, 31, REQUESTER_ID,
                        Map.of("action", "decide", "optionKey", "carrier-pigeon")));
        assertEquals(400, e.getStatus());
    }

    @Test
    void decisionNeedsTwoToFiveOptions() {
        ApiException e = assertThrows(ApiException.class,
                () -> service.openDecision(MATCH_ID, HELPER_ID, Map.of(
                        "title", "Transfer method",
                        "assignedRole", "requester",
                        "options", List.of(Map.of("key", "http", "label", "Campus HTTP")))));
        assertEquals(400, e.getStatus());
    }

    // ── Deliverables ──

    @Test
    void submitterCannotReviewOwnDeliverable() {
        var deliverable = submittedDeliverable();
        when(deliverableRepository.findByIdAndMatchId(41, MATCH_ID))
                .thenReturn(Optional.of(deliverable));

        ApiException e = assertThrows(ApiException.class,
                () -> service.reviewDeliverable(MATCH_ID, 41, HELPER_ID,
                        Map.of("action", "accept")));
        assertEquals(403, e.getStatus());
    }

    @Test
    void rejectRequiresReviewNote() {
        var deliverable = submittedDeliverable();
        when(deliverableRepository.findByIdAndMatchId(41, MATCH_ID))
                .thenReturn(Optional.of(deliverable));

        ApiException e = assertThrows(ApiException.class,
                () -> service.reviewDeliverable(MATCH_ID, 41, REQUESTER_ID,
                        Map.of("action", "reject")));
        assertEquals(400, e.getStatus());
    }

    @Test
    void requesterCanAcceptDeliverable() {
        var deliverable = submittedDeliverable();
        when(deliverableRepository.findByIdAndMatchId(41, MATCH_ID))
                .thenReturn(Optional.of(deliverable));
        when(deliverableRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        var result = service.reviewDeliverable(MATCH_ID, 41, REQUESTER_ID,
                Map.of("action", "accept"));

        assertEquals("accepted", result.get("status"));
        assertEquals(REQUESTER_ID, result.get("reviewedByUserId"));
        verify(events).record(any(), eqInt(REQUESTER_ID), any(),
                org.mockito.ArgumentMatchers.eq("deliverable.accepted"), any(), any(), any());
    }

    // ── Helpers ──

    private static Integer eqInt(int value) {
        return org.mockito.ArgumentMatchers.eq(value);
    }

    private MatchDecision openDecision() {
        var decision = new MatchDecision();
        decision.setId(31);
        decision.setMatch(match);
        decision.setRaisedBy(user(HELPER_ID));
        decision.setRaisedByRole("helper");
        decision.setAssignedRole("requester");
        decision.setTitle("Transfer method");
        decision.setStatus("open");
        decision.setOptionsJson(
                "[{\"key\":\"http\",\"label\":\"Campus HTTP\"},{\"key\":\"usb\",\"label\":\"Offline USB handoff\"}]");
        return decision;
    }

    private MatchDeliverable submittedDeliverable() {
        var deliverable = new MatchDeliverable();
        deliverable.setId(41);
        deliverable.setMatch(match);
        deliverable.setSubmittedBy(user(HELPER_ID));
        deliverable.setSubmitterRole("helper");
        deliverable.setTitle("Dataset v1");
        deliverable.setStatus("submitted");
        return deliverable;
    }

    private User user(int id) {
        var user = new User();
        user.setId(id);
        return user;
    }
}
