package nexus.campus.common.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.Map;

@Data
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ApiResponse<T> {
    private T data;
    private List<Map<String, Object>> errors;

    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(data, null);
    }

    public static ApiResponse<Void> error(List<Map<String, Object>> errors) {
        return new ApiResponse<>(null, errors);
    }

    public static ApiResponse<Void> error(String field, String message) {
        return error(List.of(Map.of("field", field, "message", message)));
    }
}
