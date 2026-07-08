package nexus.campus.auth.dto;

import lombok.Builder;
import lombok.Data;

@Data @Builder
public class TokenResponse {
    private String token;
    private Integer userId;
    private String username;
}
