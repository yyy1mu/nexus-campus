package nexus.campus.auth.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.auth.dto.LoginRequest;
import nexus.campus.auth.dto.RegisterRequest;
import nexus.campus.auth.dto.TokenResponse;
import nexus.campus.auth.service.AuthService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    public ApiResponse<TokenResponse> register(@Valid @RequestBody RegisterRequest req) {
        return ApiResponse.ok(authService.register(req));
    }

    @PostMapping("/login")
    public ApiResponse<TokenResponse> login(@Valid @RequestBody LoginRequest req) {
        return ApiResponse.ok(authService.login(req));
    }
}
