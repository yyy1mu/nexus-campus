package nexus.campus.device.controller;

import lombok.RequiredArgsConstructor;
import nexus.campus.device.entity.DeviceSignal;
import nexus.campus.device.repository.DeviceSignalRepository;
import nexus.campus.common.entity.User;
import nexus.campus.common.response.ApiResponse;
import nexus.campus.security.authorization.AgentWriteGuard;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.*;

@RestController
@RequestMapping("/api/nexus")
@RequiredArgsConstructor
public class DeviceSignalController {

    private final DeviceSignalRepository deviceSignalRepository;
    private final AgentWriteGuard guard;

    @PostMapping("/device-signals")
    public ApiResponse<Map<String, Object>> create(
            @AuthenticationPrincipal User user, @RequestBody Map<String, Object> body) {
        guard.requireConfirmedUser(user, body);
        var signal = new DeviceSignal();
        signal.setUser(user);
        signal.setPurpose((String) body.getOrDefault("purpose", "linkgo"));
        signal.setCoarseGeohash((String) body.get("coarseGeohash"));
        if (body.get("accuracyM") instanceof Number n) signal.setAccuracyM(n.intValue());
        signal.setBluetoothSeen(Boolean.TRUE.equals(body.get("bluetoothSeen")));
        signal.setShakeDetected(Boolean.TRUE.equals(body.get("shakeDetected")));
        signal.setGyroAvailable(Boolean.TRUE.equals(body.get("gyroAvailable")));
        if (body.containsKey("payload")) signal.setPayload(Objects.toString(body.get("payload"), null));
        signal.setCreatedAt(LocalDateTime.now());
        signal.setExpiresAt(LocalDateTime.now().plusMinutes(15));
        signal = deviceSignalRepository.save(signal);
        return ApiResponse.ok(toMap(signal));
    }

    @GetMapping("/me/device-signals")
    public ApiResponse<List<Map<String, Object>>> listMy(@AuthenticationPrincipal User user) {
        return ApiResponse.ok(deviceSignalRepository.findByUser_IdOrderByCreatedAtDesc(user.getId()).stream()
                .map(this::toMap).toList());
    }

    private Map<String, Object> toMap(DeviceSignal s) {
        var m = new LinkedHashMap<String, Object>();
        m.put("id", s.getId());
        m.put("purpose", s.getPurpose());
        m.put("coarseGeohash", s.getCoarseGeohash());
        m.put("accuracyM", s.getAccuracyM());
        m.put("bluetoothSeen", s.isBluetoothSeen());
        m.put("shakeDetected", s.isShakeDetected());
        m.put("gyroAvailable", s.isGyroAvailable());
        m.put("payload", s.getPayload());
        m.put("createdAt", s.getCreatedAt());
        m.put("expiresAt", s.getExpiresAt());
        return m;
    }
}
