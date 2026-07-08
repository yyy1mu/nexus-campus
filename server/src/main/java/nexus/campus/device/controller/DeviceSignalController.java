package nexus.campus.device.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.device.entity.DeviceSignal;
import nexus.campus.device.repository.DeviceSignalRepository;
import nexus.campus.common.entity.User;
import nexus.campus.common.response.ApiResponse;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class DeviceSignalController {

    private final DeviceSignalRepository deviceSignalRepository;

    @PostMapping("/device-signals")
    public ApiResponse<Map<String, Object>> create(
            @AuthenticationPrincipal User user, @RequestBody Map<String, Object> body) {
        @SuppressWarnings("unchecked")
        var attrs = (Map<String, Object>) ((Map<String, Object>) body.get("data")).get("attributes");
        var signal = new DeviceSignal();
        signal.setUser(user);
        signal.setPurpose((String) attrs.getOrDefault("purpose", "linkgo"));
        signal.setCoarseGeohash((String) attrs.get("coarseGeohash"));
        signal.setCreatedAt(LocalDateTime.now());
        signal.setExpiresAt(LocalDateTime.now().plusMinutes(15));
        signal = deviceSignalRepository.save(signal);
        return ApiResponse.ok(Map.of("id", signal.getId(), "purpose", signal.getPurpose(),
                "expiresAt", signal.getExpiresAt()));
    }

    @GetMapping("/me/device-signals")
    public ApiResponse<List<Map<String, Object>>> listMy(@AuthenticationPrincipal User user) {
        return ApiResponse.ok(deviceSignalRepository.findByUser_IdOrderByCreatedAtDesc(user.getId()).stream()
                .map(s -> Map.<String,Object>of("id", s.getId(), "purpose", s.getPurpose(),
                        "createdAt", s.getCreatedAt())).toList());
    }
}
