package com.everlaw.edu.domain.approval.event;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.connection.Message;
import org.springframework.data.redis.connection.MessageListener;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class ContentEventListener implements MessageListener {

    private final RedisTemplate<String, Object> redisTemplate;

    @Override
    public void onMessage(Message message, byte[] pattern) {
        try {
            // Redis 직렬화 장치를 사용해 역직렬화 수행
            ContentReleaseEvent event = (ContentReleaseEvent) redisTemplate.getValueSerializer().deserialize(message.getBody());
            
            if (event != null) {
                log.info("📥 [Redis Event Sub] Intercepted new content release event from Redis Pub/Sub.");
                triggerFcmPushNotification(event);
            }
        } catch (Exception e) {
            log.error("❌ [Redis Event Sub] Error processing Pub/Sub message: {}", e.getMessage(), e);
        }
    }

    /**
     * 비동기로 FCM 푸시 알림 서버로 전송하는 모의(Mock) 핵심 로직
     */
    private void triggerFcmPushNotification(ContentReleaseEvent event) {
        log.info("📲 [FCM Push Dispatcher] Constructing personalized push payload...");
        log.info("   🔔 Title: [최신 법령 반영] 컴플라이언스 필수 교육 릴리스!");
        log.info("   🔔 Body: '{}' 강좌가 신규 업데이트되었습니다. 즉시 확인해보세요.", event.title());
        log.info("   🎯 Target Job Category Segment: '{}'", event.targetJobCategory());
        log.info("   📦 Payload: [Lesson ID: {}]", event.lessonId());
        
        log.info("🚀 [FCM Send Success] Push message successfully dispatched to FCM cloud gateway.");
    }
}
