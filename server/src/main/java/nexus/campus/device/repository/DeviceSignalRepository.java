package nexus.campus.device.repository;

import nexus.campus.device.entity.DeviceSignal;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface DeviceSignalRepository extends JpaRepository<DeviceSignal, Integer> {
    List<DeviceSignal> findByUser_IdOrderByCreatedAtDesc(Integer userId);
}
