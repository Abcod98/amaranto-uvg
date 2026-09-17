package com.amaranto.chatbot;

import com.amaranto.chatbot.dto.ChatRequest;
import com.amaranto.chatbot.dto.ChatResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
@CrossOrigin(originPatterns = "*") // ponytail: abierto solo para pruebas locales; en prod queda detrás de CloudFront (mismo origen), sin CORS.
public class ChatController {

    private final ChatService chatService;

    public ChatController(ChatService chatService) {
        this.chatService = chatService;
    }

    @PostMapping({"/chat", "/api/chat"})
    public ResponseEntity<ChatResponse> chat(@RequestBody ChatRequest request) {
        try {
            return ResponseEntity.ok(new ChatResponse(chatService.reply(request)));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(new ChatResponse(e.getMessage()));
        }
    }
}
