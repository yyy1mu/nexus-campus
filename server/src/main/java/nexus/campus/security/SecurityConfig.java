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

import javax.sql.DataSource;
import java.io.IOException;
import java.util.Collections;
import java.util.Optional;

@Slf4j
@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final DataSource dataSource;

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
            .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .addFilterAt(tokenAuthFilter(), org.springframework.security.web.authentication.preauth.AbstractPreAuthenticatedProcessingFilter.class)
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(org.springframework.http.HttpMethod.OPTIONS, "/**").permitAll()
                .requestMatchers("/api/register", "/api/login").permitAll()
                .requestMatchers("/api/nexus/agent-health").permitAll()
                .requestMatchers("/api/nexus/capabilities").permitAll()
                .requestMatchers("/api/nexus/capability-labels").permitAll()
                .requestMatchers("/api/nexus/help-requests").permitAll()
                .requestMatchers("/api/nexus/forum/discussions").permitAll()
                .requestMatchers("/api/nexus/forum/discussions/*").permitAll()
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
                if (auth != null && auth.startsWith("Token ")) {
                    String token = auth.substring(6).trim();
                    findUserIdByToken(token).ifPresent(userId -> {
                        var user = new User();
                        user.setId(userId);
                        var authentication = new PreAuthenticatedAuthenticationToken(
                                user, token, Collections.singletonList(new SimpleGrantedAuthority("ROLE_USER")));
                        SecurityContextHolder.getContext().setAuthentication(authentication);
                    });
                }
                chain.doFilter(request, response);
            }
        };
    }

    private Optional<Integer> findUserIdByToken(String token) {
        try (var conn = dataSource.getConnection();
             var stmt = conn.prepareStatement("SELECT user_id FROM api_keys WHERE token_key = ?")) {
            stmt.setString(1, token);
            try (var rs = stmt.executeQuery()) {
                if (rs.next()) return Optional.of(rs.getInt("user_id"));
            }
        } catch (Exception e) {
            log.warn("Token lookup failed", e);
        }
        return Optional.empty();
    }
}
