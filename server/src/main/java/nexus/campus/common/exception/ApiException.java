package nexus.campus.common.exception;

import lombok.Getter;
import java.util.Map;

@Getter
public class ApiException extends RuntimeException {
    private final int status;
    private final Map<String, String> errors;

    public ApiException(int status, String field, String message) {
        super(message);
        this.status = status;
        this.errors = Map.of(field, message);
    }

    public ApiException(int status, String message) {
        super(message);
        this.status = status;
        this.errors = Map.of("detail", message);
    }

    public static ApiException notFound(String resource, Object id) {
        return new ApiException(404, "detail", resource + " #" + id + " not found");
    }

    public static ApiException forbidden() {
        return new ApiException(403, "detail", "Permission denied");
    }

    public static ApiException badRequest(String field, String message) {
        return new ApiException(400, field, message);
    }

    public static ApiException unauthenticated() {
        return new ApiException(401, "detail", "Authentication required");
    }
}
