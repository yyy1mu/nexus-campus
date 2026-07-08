package nexus.campus.auth.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class LoginRequest {
    @NotBlank
    private String identification;

    @NotBlank
    private String password;
}
