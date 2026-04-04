// WEBHOOK INTEGRATION GUIDE - Backend Requirements
// 
// Este archivo es SOLO una referencia. El código backend (Spring Boot) ya debe estar implementado.
// Úsalo como checklist para verificar que tu backend está listo.

// ============================================================================
// ✅ BACKEND CHECKLIST (Java Spring Boot)
// ============================================================================

// 1. CONTROLLER - Debe existir endpoint receptor:
/*
@RestController
@RequestMapping("/api/webhooks")
public class WebhookController {
    
    @PostMapping("/matias")
    public ResponseEntity<Void> receiveWebhook(@RequestBody MatiasWebhookEvent event,
                                                @RequestHeader("X-Webhook-Secret") String secret) {
        // ✅ Validar secret
        // ✅ Procesar evento
        // ✅ Distribuir a través de WebSocket
        // ✅ Guardar en BD si es necesario
        return ResponseEntity.ok().build();
    }
    
    // Endpoint de prueba (useful para testing)
    @PostMapping("/matias/test")
    public ResponseEntity<Void> testWebhook(@RequestBody MatiasWebhookEvent event) {
        // Simula un evento de Matias
        return ResponseEntity.ok().build();
    }
}
*/

// 2. WEBSOCKET CONFIG - Debe exponer `/topic/matias-webhooks`
/*
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
    
    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        config
            .enableSimpleBroker("/topic")
            .setHeartbeatValue(new long[]{10000, 10000});
        
        config.setApplicationDestinationPrefixes("/app");
    }
    
    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry
            .addEndpoint("/ws")
            .setAllowedOriginPatterns("*")
            .withSockJS();
    }
}
*/

// 3. SERVICE - Debe distribuir eventos:
/*
@Service
public class WebhookService {
    
    @Autowired
    private SimpMessagingTemplate messagingTemplate;
    
    public void processEvent(MatiasWebhookEvent event) {
        // Guardar en BD si es necesario
        // webhookEventRepository.save(event);
        
        // Distribuir a todos los clientes conectados
        messagingTemplate.convertAndSend(
            "/topic/matias-webhooks",
            Map.of(
                "tipo", "WEBHOOK_EVENTO",
                "event", event.getEvent(),
                "timestamp", event.getTimestamp(),
                "data", event.getData()
            )
        );
    }
}
*/

// 4. PROPERTIES - Configuración requerida en application.properties:
/*
# WebSocket
spring.application.name=vercy-motos-backend

# Matias Integration
matias.api.key=${MATIAS_API_KEY}
matias.api.secret=${MATIAS_API_SECRET}
matias.webhook.url=${MATIAS_WEBHOOK_URL:http://localhost:8081/api/webhooks/matias}
matias.webhook.secret=${MATIAS_WEBHOOK_SECRET}

# CORS
spring.web.cors.allowedOrigins=*
spring.web.cors.allowedMethods=GET,POST,PUT,DELETE,OPTIONS
*/

// ============================================================================
// 🔌 FLUTTER CONNECTION POINTS
// ============================================================================

// El cliente Flutter se conecta a este endpoint WebSocket:
// ws://localhost:8081/topic/matias-webhooks
// or
// wss://vercy-motos-app.onrender.com/topic/matias-webhooks

// Formato esperado del mensaje:
/*
{
  "tipo": "WEBHOOK_EVENTO",
  "id": "evt_123",
  "event": "document.accepted|document.rejected|document.created|etc",
  "timestamp": "2026-04-02T10:30:00+00:00",
  "data": {
    "document_id": "doc_001",
    "document_number": "SETP00123",
    "document_type": "INVOICE",
    "status": "ACEPTADO",
    "client_name": "John Doe",
    "total_amount": 150000,
    "message": "opcional para rechazos"
  }
}
*/

// ============================================================================
// 📋 REGISTER WEBHOOK
// ============================================================================

// Endpoint para registrar el webhook con Matias API:
// POST /api/matias/webhooks/register
// 
// Respuesta esperada:
// {
//   "success": true,
//   "webhook_id": "wh_xyz789",
//   "url": "https://vercy-motos-app.onrender.com/api/webhooks/matias",
//   "events": ["document.created", "document.accepted", "document.rejected", ...]
// }

// ============================================================================
// 🧪 TESTING
// ============================================================================

// Simular evento desde Postman/cURL:
/*
POST http://localhost:8081/api/webhooks/matias/test
Content-Type: application/json

{
  "id": "test-evt-1",
  "event": "document.accepted",
  "timestamp": "2026-04-02T10:30:00",
  "data": {
    "document_id": "doc-001",
    "document_number": "SETP00123",
    "document_type": "INVOICE",
    "status": "ACEPTADO",
    "total_amount": 150000
  }
}
*/

// El evento debe llegar a todos los clientes Flutter conectados en ~1-2ms

// ============================================================================
// 🛡️ SECURITY CHECKLIST
// ============================================================================

// - [ ] Validar webhook secret en cada evento
// - [ ] Usar HTTPS (wss://) en producción
// - [ ] Permitir CORS solo desde dominios conocidos (opcional)
// - [ ] Loguear todos los eventos recibidos
// - [ ] Implementar rate limiting para webhook endpoint
// - [ ] Validar estructura JSON antes de procesar
// - [ ] Usar HTTPS para registrar webhook con Matias

// ============================================================================
// 📊 EXPECTED LOG OUTPUT
// ============================================================================

// Backend:
// [INFO] Webhook received: event=document.accepted, documentId=doc-001
// [INFO] Broadcasting to WebSocket subscribers...

// Flutter:
// [LOG] 📨 Evento recibido: document.accepted
// [LOG] ✅ Factura aceptada por DIAN #SETP00123
