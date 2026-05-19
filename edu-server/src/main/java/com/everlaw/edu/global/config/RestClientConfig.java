package com.everlaw.edu.global.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

@Configuration
public class RestClientConfig {

    @Value("${ai-engine.url:http://localhost:8000}")
    private String aiEngineUrl;

    @Bean
    public RestClient aiEngineRestClient() {
        return RestClient.builder()
                .baseUrl(aiEngineUrl)
                .defaultHeader("Content-Type", "application/json")
                .build();
    }
}
