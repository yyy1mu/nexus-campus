package nexus.campus.agent.memory.dto;

import lombok.Data;

import java.util.List;

@Data
public class MatchMemoryShareRequest {
    private List<Integer> memoryIds;
    private Boolean userConfirmed;
}
