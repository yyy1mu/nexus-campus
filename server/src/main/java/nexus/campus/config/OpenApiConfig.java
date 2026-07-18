package nexus.campus.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI nexusOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("Nexus Campus REST API")
                        .version("0.3.0")
                        .description("Spring Boot generated OpenAPI 3 contract for the Nexus Campus REST API."))
                .components(new Components()
                        .addSecuritySchemes("tokenAuth", new SecurityScheme()
                                .type(SecurityScheme.Type.APIKEY)
                                .in(SecurityScheme.In.HEADER)
                                .name("Authorization")
                                .description("Use `Token <token>`.")))
                .addSecurityItem(new SecurityRequirement().addList("tokenAuth"));
    }
}
