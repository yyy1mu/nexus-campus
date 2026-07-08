package nexus.campus.common.exception;

import nexus.campus.common.response.ApiResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ApiResponse<Void>> handleApi(ApiException ex) {
        var errors = new ArrayList<Map<String, Object>>();
        ex.getErrors().forEach((field, message) ->
            errors.add(Map.of("field", field, "message", message)));
        return ResponseEntity.status(ex.getStatus()).body(ApiResponse.error(errors));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Void>> handleValidation(MethodArgumentNotValidException ex) {
        var errors = ex.getBindingResult().getFieldErrors().stream()
                .map(fe -> Map.<String, Object>of("field", fe.getField(), "message", fe.getDefaultMessage()))
                .toList();
        return ResponseEntity.badRequest().body(ApiResponse.error(errors));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleGeneric(Exception ex) {
        log.error("Unhandled exception", ex);
        var msg = ex.getMessage() != null ? ex.getMessage() : "Internal server error";
        return ResponseEntity.status(500).body(ApiResponse.error("detail", msg));
    }
}
