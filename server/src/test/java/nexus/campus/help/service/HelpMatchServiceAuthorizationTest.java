package nexus.campus.help.service;

import nexus.campus.common.entity.User;
import nexus.campus.common.exception.ApiException;
import nexus.campus.common.validation.PayloadValidator;
import nexus.campus.help.entity.HelpMatch;
import nexus.campus.help.entity.HelpRequest;
import nexus.campus.help.repository.HelpDispatchRepository;
import nexus.campus.help.repository.HelpMatchMessageRepository;
import nexus.campus.help.repository.HelpMatchRepository;
import nexus.campus.help.repository.HelpRequestRepository;
import nexus.campus.help.repository.MatchDecisionRepository;
import nexus.campus.help.repository.MatchDeliverableRepository;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

class HelpMatchServiceAuthorizationTest {
    @Test
    void nonParticipantCannotCompleteAcceptedMatch() {
        HelpMatchRepository matchRepository = mock(HelpMatchRepository.class);
        HelpMatchService service = new HelpMatchService(
                matchRepository,
                mock(HelpDispatchRepository.class),
                mock(HelpMatchMessageRepository.class),
                mock(HelpRequestRepository.class),
                mock(MatchDeliverableRepository.class),
                mock(MatchDecisionRepository.class),
                mock(MatchEventRecorder.class),
                mock(PayloadValidator.class));

        User requester = user(4);
        User helper = user(5);
        HelpRequest request = new HelpRequest();
        request.setRequester(requester);
        HelpMatch match = new HelpMatch();
        match.setId(12);
        match.setHelpRequest(request);
        match.setHelper(helper);
        match.setStatus("accepted");
        when(matchRepository.findById(12)).thenReturn(Optional.of(match));

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.updateStatus(12, 99, "completed", null, null));

        assertEquals(403, exception.getStatus());
        verify(matchRepository, never()).save(any());
    }

    private User user(int id) {
        User user = new User();
        user.setId(id);
        return user;
    }
}
