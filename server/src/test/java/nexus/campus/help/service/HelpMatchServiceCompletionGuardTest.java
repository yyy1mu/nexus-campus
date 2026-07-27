package nexus.campus.help.service;

import nexus.campus.common.entity.User;
import nexus.campus.common.exception.ApiException;
import nexus.campus.common.validation.PayloadValidator;
import nexus.campus.help.entity.HelpMatch;
import nexus.campus.help.entity.HelpMatchMessage;
import nexus.campus.help.entity.HelpRequest;
import nexus.campus.help.entity.MatchDecision;
import nexus.campus.help.entity.MatchDeliverable;
import nexus.campus.help.repository.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class HelpMatchServiceCompletionGuardTest {

    private static final int REQUESTER_ID = 4;
    private static final int HELPER_ID = 5;

    private HelpMatchRepository matchRepository;
    private HelpMatchMessageRepository messageRepository;
    private HelpRequestRepository helpRequestRepository;
    private MatchDeliverableRepository deliverableRepository;
    private MatchDecisionRepository decisionRepository;
    private MatchEventRecorder events;
    private HelpMatchService service;
    private HelpMatch match;
    private HelpRequest request;

    @BeforeEach
    void setUp() {
        matchRepository = mock(HelpMatchRepository.class);
        messageRepository = mock(HelpMatchMessageRepository.class);
        helpRequestRepository = mock(HelpRequestRepository.class);
        deliverableRepository = mock(MatchDeliverableRepository.class);
        decisionRepository = mock(MatchDecisionRepository.class);
        events = mock(MatchEventRecorder.class);
        service = new HelpMatchService(
                matchRepository,
                mock(HelpDispatchRepository.class),
                messageRepository,
                helpRequestRepository,
                deliverableRepository,
                decisionRepository,
                events,
                new PayloadValidator());

        request = new HelpRequest();
        request.setRequester(user(REQUESTER_ID));
        request.setStatus("matched");
        match = new HelpMatch();
        match.setId(12);
        match.setHelpRequest(request);
        match.setHelper(user(HELPER_ID));
        match.setStatus("accepted");
        when(matchRepository.findById(12)).thenReturn(Optional.of(match));
        when(matchRepository.save(any())).thenAnswer(i -> i.getArgument(0));
    }

    @Test
    void helperCannotCompleteMatch() {
        ApiException e = assertThrows(ApiException.class,
                () -> service.updateStatus(12, HELPER_ID, "completed", null, null));

        assertEquals(403, e.getStatus());
        assertEquals("accepted", match.getStatus());
    }

    @Test
    void pendingDeliverableBlocksCompletion() {
        var pending = new MatchDeliverable();
        pending.setStatus("submitted");
        when(deliverableRepository.findByMatchIdAndStatus(12, "submitted"))
                .thenReturn(List.of(pending));

        ApiException e = assertThrows(ApiException.class,
                () -> service.updateStatus(12, REQUESTER_ID, "completed", null, null));

        assertEquals(400, e.getStatus());
        assertEquals("accepted", match.getStatus());
    }

    @Test
    void openDecisionBlocksCompletion() {
        when(deliverableRepository.findByMatchIdAndStatus(12, "submitted")).thenReturn(List.of());
        var open = new MatchDecision();
        open.setStatus("open");
        when(decisionRepository.findByMatchIdAndStatus(12, "open")).thenReturn(List.of(open));

        ApiException e = assertThrows(ApiException.class,
                () -> service.updateStatus(12, REQUESTER_ID, "completed", null, null));

        assertEquals(400, e.getStatus());
        assertEquals("open", open.getStatus());
        assertEquals("accepted", match.getStatus());
    }

    @Test
    void requesterCompletesSettledCollaboration() {
        when(deliverableRepository.findByMatchIdAndStatus(12, "submitted")).thenReturn(List.of());
        when(decisionRepository.findByMatchIdAndStatus(12, "open")).thenReturn(List.of());

        var result = service.updateStatus(12, REQUESTER_ID, "completed", null, null);

        assertEquals("completed", result.getStatus());
        assertEquals("closed", request.getStatus());
        verify(events).record(any(), eq(REQUESTER_ID), eq("requester"),
                eq("match.completed"), eq("match"), eq(12), any());
    }

    @Test
    void cancellationAutoCancelsOpenDecisions() {
        var open = new MatchDecision();
        open.setStatus("open");
        when(decisionRepository.findByMatchIdAndStatus(12, "open")).thenReturn(List.of(open));
        when(decisionRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        var result = service.updateStatus(12, HELPER_ID, "cancelled", null, null);

        assertEquals("cancelled", result.getStatus());
        assertEquals("cancelled", open.getStatus());
        verify(events).record(any(), eq(HELPER_ID), eq("helper"),
                eq("match.cancelled"), eq("match"), eq(12), any());
    }

    @Test
    void messageReplayWithSameClientRequestIdReturnsOriginal() {
        var original = new HelpMatchMessage();
        original.setId(7);
        original.setMatch(match);
        original.setUser(user(HELPER_ID));
        original.setContent("Checksum is 51a9...");
        when(messageRepository.findByMatchIdAndClientRequestId(12, "msg-1"))
                .thenReturn(Optional.of(original));

        var result = service.sendMessage(12, HELPER_ID, "Checksum is 51a9...", null, "update", "msg-1");

        assertEquals(7, result.getId());
        verify(messageRepository, never()).save(any());
    }

    @Test
    void messageRejectsUnknownKind() {
        ApiException e = assertThrows(ApiException.class,
                () -> service.sendMessage(12, HELPER_ID, "hello", null, "telepathy", null));
        assertEquals(400, e.getStatus());
    }

    private User user(int id) {
        var user = new User();
        user.setId(id);
        return user;
    }
}
