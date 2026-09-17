package com.amaranto.chatbot;

import com.amaranto.chatbot.dto.Message;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.List;

@Component
public class OpenRouterClient {

    private final RestClient restClient;
    private final String model;
    private final int maxTokens;

    public OpenRouterClient(
            @Value("${openrouter.api-key}") String apiKey,
            @Value("${openrouter.model}") String model,
            @Value("${openrouter.max-tokens}") int maxTokens) {
        this.model = model;
        this.maxTokens = maxTokens;
        this.restClient = RestClient.builder()
                .baseUrl("https://openrouter.ai/api/v1")
                .defaultHeader("Authorization", "Bearer " + apiKey)
                .defaultHeader("Content-Type", "application/json")
                .build();
    }

    record ChatCompletionRequest(String model, List<Message> messages, int max_tokens) {
    }

    record Choice(Message message) {
    }

    record ChatCompletionResponse(List<Choice> choices) {
    }

    public String complete(List<Message> messages) {
        ChatCompletionResponse response = restClient.post()
                .uri("/chat/completions")
                .body(new ChatCompletionRequest(model, messages, maxTokens))
                .retrieve()
                .body(ChatCompletionResponse.class);

        if (response == null || response.choices() == null || response.choices().isEmpty()) {
            throw new IllegalStateException("OpenRouter devolvió una respuesta vacía");
        }
        return response.choices().get(0).message().content();
    }
}
