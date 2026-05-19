package com.everlaw.edu.domain.approval.event;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class ContentEventPublisher {

    private final RedisTemplate<String, Object> redisTemplate;
    
    public static final String CHANNEL_NAME = "everlaw:content:events";

    public void publishContentRelease(Long lessonId, String targetJobCategory, String title) {
        ContentReleaseEvent event = new ContentReleaseEvent(lessonId, targetJobCategory, title);
        log.info("📢 [Redis Event Pub] Publishing content release event: {}", event);
        try {
            redisTemplate.convertAndSend(CHANNEL_NAME, event);
        } catch (Exception e) {
            log.error("❌ [Redis Event Pub] Event publication failed: {}", e.getMessage(), e);
        }
    }
}
