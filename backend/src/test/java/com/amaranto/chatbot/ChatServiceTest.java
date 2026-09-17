package com.amaranto.chatbot;

import com.amaranto.chatbot.dto.ChatRequest;
import com.amaranto.chatbot.dto.Message;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ChatServiceTest {

    @Test
    void includesSystemPromptAndUserMessageInOrder() throws Exception {
        OpenRouterClient client = mock(OpenRouterClient.class);
        when(client.complete(anyList())).thenReturn("hola, en que te ayudo");

        ChatService service = new ChatService(client);
        String reply = service.reply(new ChatRequest("hola", List.of(new Message("user", "previo"))));

        assertEquals("hola, en que te ayudo", reply);

        var captor = org.mockito.ArgumentCaptor.forClass(List.class);
        verify(client).complete(captor.capture());
        List<Message> sent = captor.getValue();

        assertEquals("system", sent.get(0).role());
        assertEquals("user", sent.get(1).role());
        assertEquals("previo", sent.get(1).content());
        assertEquals("user", sent.get(2).role());
        assertEquals("hola", sent.get(2).content());
    }

    @Test
    void fallsBackWhenClientThrows() throws Exception {
        OpenRouterClient client = mock(OpenRouterClient.class);
        when(client.complete(anyList())).thenThrow(new RuntimeException("boom"));

        ChatService service = new ChatService(client);
        String reply = service.reply(new ChatRequest("hola", List.of()));

        assertEquals(ChatService.FALLBACK_REPLY, reply);
    }

    @Test
    void rejectsMessagesThatAreTooLong() throws Exception {
        OpenRouterClient client = mock(OpenRouterClient.class);
        ChatService service = new ChatService(client);

        String tooLong = "a".repeat(ChatService.MAX_MESSAGE_LENGTH + 1);
        assertThrows(IllegalArgumentException.class,
                () -> service.reply(new ChatRequest(tooLong, List.of())));
    }
}
