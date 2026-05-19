package com.everlaw.edu.domain.approval.event;

import java.io.Serializable;

public record ContentReleaseEvent(
        Long lessonId,
        String targetJobCategory,
        String title
) implements Serializable {
}
