package nexus.campus.help.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;
import nexus.campus.common.enums.HelpRequestStatus;
import nexus.campus.common.enums.MeetingSafetyState;
import nexus.campus.common.enums.Urgency;

import java.util.List;

@Data
public class HelpRequestCreateRequest {
    @NotBlank @Size(max = 200)
    private String title;

    @NotBlank @Size(max = 2000)
    private String summary;

    @Size(max = 20000)
    private String content;

    private List<String> neededLabels;
    private String categoryLabel;
    private Urgency urgency = Urgency.normal;

    @Size(max = 255)
    private String locationHint;

    private MeetingSafetyState meetingSafetyState = MeetingSafetyState.not_arranged;
    private Boolean userConfirmed;
}
