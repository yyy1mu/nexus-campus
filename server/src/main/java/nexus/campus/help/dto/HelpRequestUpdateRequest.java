package nexus.campus.help.dto;

import lombok.Data;
import nexus.campus.common.enums.HelpRequestStatus;
import nexus.campus.common.enums.MeetingSafetyState;
import java.util.List;

@Data
public class HelpRequestUpdateRequest {
    private HelpRequestStatus status;
    private MeetingSafetyState meetingSafetyState;
    private String locationHint;
    private String summary;
    private List<String> neededLabels;
    private String agentContext;
    private Boolean userConfirmed;
}
