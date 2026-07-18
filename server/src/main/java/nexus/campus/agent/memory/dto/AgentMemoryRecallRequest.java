package nexus.campus.agent.memory.dto;

import lombok.Data;

import java.util.List;

@Data
public class AgentMemoryRecallRequest {
    private String query;
    private List<String> kinds;
    private List<String> tags;
    private Integer limit = 10;
}
