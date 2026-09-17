package com.amaranto.chatbot;

import com.amaranto.chatbot.dto.ChatRequest;
import com.amaranto.chatbot.dto.Message;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

@Service
public class ChatService {

    private static final Logger log = LoggerFactory.getLogger(ChatService.class);

    static final int MAX_MESSAGE_LENGTH = 500;
    static final int MAX_HISTORY_ENTRIES = 6;
    static final String FALLBACK_REPLY = "Disculpá, tuve un problema para responder en este momento. "
            + "Podés escribirnos directo por WhatsApp o a ventas@amarantoguatemala.com y te ayudamos enseguida.";

    private final OpenRouterClient openRouterClient;
    private final String systemPrompt;

    public ChatService(OpenRouterClient openRouterClient) throws IOException {
        this.openRouterClient = openRouterClient;
        this.systemPrompt = new String(
                new ClassPathResource("system-prompt.txt").getInputStream().readAllBytes(),
                StandardCharsets.UTF_8);
    }

    public String reply(ChatRequest request) {
        String userMessage = request.message() == null ? "" : request.message().trim();
        if (userMessage.isEmpty()) {
            throw new IllegalArgumentException("El mensaje no puede estar vacío");
        }
        if (userMessage.length() > MAX_MESSAGE_LENGTH) {
            throw new IllegalArgumentException("El mensaje es demasiado largo");
        }

        List<Message> messages = new ArrayList<>();
        messages.add(new Message("system", systemPrompt));

        List<Message> history = request.history();
        int fromIndex = Math.max(0, history.size() - MAX_HISTORY_ENTRIES);
        messages.addAll(history.subList(fromIndex, history.size()));

        messages.add(new Message("user", userMessage));

        try {
            return openRouterClient.complete(messages);
        } catch (Exception e) {
            log.error("Fallo la llamada a OpenRouter", e);
            return FALLBACK_REPLY;
        }
    }
}
