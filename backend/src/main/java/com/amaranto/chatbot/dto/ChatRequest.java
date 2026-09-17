package com.amaranto.chatbot.dto;

import java.util.List;

public record ChatRequest(String message, List<Message> history) {
    public ChatRequest {
        history = history == null ? List.of() : history;
    }
}
