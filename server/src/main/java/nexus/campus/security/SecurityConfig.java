package nexus.campus.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import nexus.campus.common.entity.User;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.preauth.PreAuthenticatedAuthenticationToken;
import org.springframework.web.filter.OncePerRequestFilter;

import nexus.campus.auth.service.TokenService;
import org.springframework.dao.DataAccessException;
import java.io.IOException;
import java.util.Collections;
import java.util.Optional;

@Slf4j
@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final TokenService tokens;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .cors(cors -> cors.configurationSource(request -> {
                var config = new org.springframework.web.cors.CorsConfiguration();
                config.addAllowedOriginPattern("*");
                config.addAllowedMethod("*");
                config.addAllowedHeader("*");
                config.setAllowCredentials(true);
                return config;
            }))
            .csrf(csrf -> csrf.disable())
            .exceptionHandling(errors -> errors
                .authenticationEntryPoint((request, response, exception) -> authenticationError(response, 401))
                .accessDeniedHandler((request, response, exception) -> authenticationError(response, 403)))
            .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .addFilterAt(tokenAuthFilter(), org.springframework.security.web.authentication.preauth.AbstractPreAuthenticatedProcessingFilter.class)
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(org.springframework.http.HttpMethod.OPTIONS, "/**").permitAll()
                .requestMatchers("/api/register", "/api/login").permitAll()
                .requestMatchers("/v3/api-docs/**", "/v3/api-docs.yaml", "/swagger-ui/**", "/swagger-ui.html").permitAll()
                .requestMatchers("/llms.txt", "/docs/**", "/.well-known/**", "/schemas/**").permitAll()
                .requestMatchers("/api/nexus/agent-health").permitAll()
                .requestMatchers(org.springframework.http.HttpMethod.GET, "/api/nexus/resources", "/api/nexus/resources/*").permitAll()
                .requestMatchers(org.springframework.http.HttpMethod.GET, "/api/nexus/capabilities").permitAll()
                .requestMatchers(org.springframework.http.HttpMethod.GET, "/api/nexus/capability-labels").permitAll()
                .requestMatchers(org.springframework.http.HttpMethod.GET, "/api/nexus/help-requests").permitAll()
                .requestMatchers(org.springframework.http.HttpMethod.GET, "/api/nexus/help-requests/*").permitAll()
                .requestMatchers(org.springframework.http.HttpMethod.GET, "/api/nexus/forum/discussions").permitAll()
                .requestMatchers(org.springframework.http.HttpMethod.GET, "/api/nexus/forum/discussions/*").permitAll()
                .requestMatchers(org.springframework.http.HttpMethod.GET, "/api/nexus/forum/tags").permitAll()
                .anyRequest().authenticated()
            );
        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public OncePerRequestFilter tokenAuthFilter() {
        return new OncePerRequestFilter() {
            @Override
            protected void doFilterInternal(HttpServletRequest request,
                                            HttpServletResponse response,
                                            FilterChain chain) throws ServletException, IOException {
                String auth = request.getHeader("Authorization");
                if (auth != null) {
                    if (!auth.startsWith("Token ")) { authenticationError(response, 401); return; }
                    String token = auth.substring(6).trim();
                    Optional<Integer> userId;
                    try { userId = tokens.findUserId(token); }
                    catch (DataAccessException e) {
                        // A database outage is not evidence that the credential is invalid.
                        log.warn("Authentication storage unavailable");
                        authenticationError(response, 503);
                        return;
                    }
                    if (userId.isEmpty()) { authenticationError(response, 401); return; }
                    var user = new User();
                    user.setId(userId.get());
                    var authentication = new PreAuthenticatedAuthenticationToken(
                        user, token, Collections.singletonList(new SimpleGrantedAuthority("ROLE_USER")));
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                }
                chain.doFilter(request, response);
            }
        };
    }

    private static void authenticationError(HttpServletResponse response, int status) throws IOException {
        response.setStatus(status);
        response.setContentType("application/json;charset=UTF-8");
        String message = status == 503 ? "Authentication service temporarily unavailable"
            : status == 403 ? "Permission denied" : "Authentication required";
        response.getWriter().write("{\"errors\":[{\"field\":\"authentication\",\"message\":\"" + message + "\"}]}");
    }
}
