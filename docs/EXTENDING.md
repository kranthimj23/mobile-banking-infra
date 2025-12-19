# Extending the Platform

This guide explains how to add new microservices to the Mobile Banking Platform, specifically focusing on the planned Loan Service and Notification Service.

## Architecture Extension Points

The platform is designed with extensibility in mind. New services can be added without modifying existing services by following these patterns:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Extended Architecture                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                         API Gateway                                   │   │
│  │  Routes: /api/v1/auth/**, /api/v1/users/**, /api/v1/loans/**,       │   │
│  │          /api/v1/notifications/**                                    │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│         │              │              │                │                     │
│         ▼              ▼              ▼                ▼                     │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────────────┐         │
│  │   Auth     │ │   User     │ │   Loan     │ │   Notification   │         │
│  │  Service   │ │  Service   │ │  Service   │ │     Service      │         │
│  │  (8081)    │ │  (8082)    │ │  (8083)    │ │     (8084)       │         │
│  └────────────┘ └────────────┘ └────────────┘ └──────────────────┘         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Adding Loan Service

### Step 1: Create Service Directory

```bash
mkdir -p services/loan-service/src/main/java/com/mobilebanking/loan/{config,controller,dto,entity,repository,service}
mkdir -p services/loan-service/src/main/resources
mkdir -p services/loan-service/src/test/java/com/mobilebanking/loan
```

### Step 2: Create pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
    </parent>
    
    <groupId>com.mobilebanking</groupId>
    <artifactId>loan-service</artifactId>
    <version>1.0.0</version>
    <name>loan-service</name>
    
    <properties>
        <java.version>17</java.version>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>io.micrometer</groupId>
            <artifactId>micrometer-registry-prometheus</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springdoc</groupId>
            <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
            <version>2.3.0</version>
        </dependency>
    </dependencies>
</project>
```

### Step 3: Create Entity Classes

```java
// Loan.java
@Entity
@Table(name = "loans")
public class Loan {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;
    
    @Column(nullable = false)
    private String userId;
    
    @Column(nullable = false)
    private BigDecimal amount;
    
    @Column(nullable = false)
    private BigDecimal interestRate;
    
    @Column(nullable = false)
    private Integer termMonths;
    
    @Enumerated(EnumType.STRING)
    private LoanStatus status;
    
    @Enumerated(EnumType.STRING)
    private LoanType type;
    
    private LocalDateTime applicationDate;
    private LocalDateTime approvalDate;
    private LocalDateTime disbursementDate;
    
    // getters, setters
}

// LoanStatus.java
public enum LoanStatus {
    PENDING,
    UNDER_REVIEW,
    APPROVED,
    REJECTED,
    DISBURSED,
    ACTIVE,
    PAID_OFF,
    DEFAULTED
}

// LoanType.java
public enum LoanType {
    PERSONAL,
    HOME,
    AUTO,
    EDUCATION,
    BUSINESS
}
```

### Step 4: Create Controller

```java
@RestController
@RequestMapping("/api/v1/loans")
public class LoanController {
    
    private final LoanService loanService;
    
    @PostMapping("/apply")
    public ResponseEntity<ApiResponse<LoanResponse>> applyForLoan(
            @Valid @RequestBody LoanApplicationRequest request,
            @RequestHeader("X-User-Id") String userId) {
        LoanResponse loan = loanService.applyForLoan(userId, request);
        return ResponseEntity.ok(ApiResponse.success(loan));
    }
    
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<LoanResponse>> getLoan(@PathVariable String id) {
        LoanResponse loan = loanService.getLoanById(id);
        return ResponseEntity.ok(ApiResponse.success(loan));
    }
    
    @GetMapping("/user/{userId}")
    public ResponseEntity<ApiResponse<List<LoanResponse>>> getUserLoans(
            @PathVariable String userId) {
        List<LoanResponse> loans = loanService.getLoansByUserId(userId);
        return ResponseEntity.ok(ApiResponse.success(loans));
    }
    
    @PostMapping("/{id}/approve")
    public ResponseEntity<ApiResponse<LoanResponse>> approveLoan(@PathVariable String id) {
        LoanResponse loan = loanService.approveLoan(id);
        return ResponseEntity.ok(ApiResponse.success(loan));
    }
}
```

### Step 5: Create Helm Chart

```bash
cp -r helm/charts/auth-service helm/charts/loan-service
```

Update `helm/charts/loan-service/Chart.yaml`:
```yaml
apiVersion: v2
name: loan-service
description: Loan Service for Mobile Banking Platform
type: application
version: 1.0.0
appVersion: "1.0.0"
```

Update `helm/charts/loan-service/values.yaml`:
```yaml
replicaCount: 2

image:
  repository: mobile-banking/loan-service
  tag: "1.0.0"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8083

env:
  SPRING_PROFILES_ACTIVE: "prod"
  DB_HOST: "postgres-loan"
  DB_PORT: "5432"
  DB_NAME: "loan_db"
```

### Step 6: Update API Gateway Routes

Add to `api-gateway/src/main/resources/application.yml`:
```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: loan-service
          uri: lb://loan-service
          predicates:
            - Path=/api/v1/loans/**
          filters:
            - name: CircuitBreaker
              args:
                name: loanServiceCircuitBreaker
                fallbackUri: forward:/fallback/loan
```

### Step 7: Create Jenkins Pipeline

```bash
cp jenkins/pipelines/Jenkinsfile-auth-service jenkins/pipelines/Jenkinsfile-loan-service
```

Update service name in the Jenkinsfile:
```groovy
environment {
    SERVICE_NAME = 'loan-service'
    // ... rest of configuration
}
```

## Adding Notification Service

### Step 1: Create Service Structure

```bash
mkdir -p services/notification-service/src/main/java/com/mobilebanking/notification/{config,controller,dto,entity,repository,service,provider}
```

### Step 2: Define Notification Types

```java
// NotificationType.java
public enum NotificationType {
    EMAIL,
    SMS,
    PUSH,
    IN_APP
}

// NotificationStatus.java
public enum NotificationStatus {
    PENDING,
    SENT,
    DELIVERED,
    FAILED,
    READ
}

// Notification.java
@Entity
@Table(name = "notifications")
public class Notification {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;
    
    @Column(nullable = false)
    private String userId;
    
    @Enumerated(EnumType.STRING)
    private NotificationType type;
    
    @Enumerated(EnumType.STRING)
    private NotificationStatus status;
    
    private String subject;
    private String content;
    private String recipient;
    
    private LocalDateTime createdAt;
    private LocalDateTime sentAt;
    private LocalDateTime readAt;
}
```

### Step 3: Create Notification Providers

```java
// NotificationProvider.java
public interface NotificationProvider {
    NotificationType getType();
    void send(Notification notification);
}

// EmailNotificationProvider.java
@Component
public class EmailNotificationProvider implements NotificationProvider {
    
    private final JavaMailSender mailSender;
    
    @Override
    public NotificationType getType() {
        return NotificationType.EMAIL;
    }
    
    @Override
    public void send(Notification notification) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(notification.getRecipient());
        message.setSubject(notification.getSubject());
        message.setText(notification.getContent());
        mailSender.send(message);
    }
}

// PushNotificationProvider.java
@Component
public class PushNotificationProvider implements NotificationProvider {
    
    @Override
    public NotificationType getType() {
        return NotificationType.PUSH;
    }
    
    @Override
    public void send(Notification notification) {
        // Integrate with Firebase Cloud Messaging or similar
    }
}
```

### Step 4: Create Event-Driven Integration

For asynchronous notification processing, use message queues:

```java
// NotificationEventListener.java
@Component
public class NotificationEventListener {
    
    private final NotificationService notificationService;
    
    @RabbitListener(queues = "notification-queue")
    public void handleNotificationEvent(NotificationEvent event) {
        notificationService.processNotification(event);
    }
}

// NotificationEvent.java
public class NotificationEvent {
    private String userId;
    private NotificationType type;
    private String templateId;
    private Map<String, Object> templateData;
}
```

### Step 5: Add RabbitMQ to Docker Compose

```yaml
rabbitmq:
  image: rabbitmq:3-management-alpine
  container_name: rabbitmq
  ports:
    - "5672:5672"
    - "15672:15672"
  environment:
    RABBITMQ_DEFAULT_USER: admin
    RABBITMQ_DEFAULT_PASS: admin
  networks:
    - mobile-banking
```

## Service Communication Patterns

### Synchronous (REST)

For direct service-to-service calls:

```java
@FeignClient(name = "user-service")
public interface UserServiceClient {
    
    @GetMapping("/api/v1/users/{id}")
    ApiResponse<UserResponse> getUserById(@PathVariable String id);
}
```

### Asynchronous (Events)

For event-driven communication:

```java
// Event Publisher
@Component
public class LoanEventPublisher {
    
    private final RabbitTemplate rabbitTemplate;
    
    public void publishLoanApproved(Loan loan) {
        LoanApprovedEvent event = new LoanApprovedEvent(loan);
        rabbitTemplate.convertAndSend("loan-exchange", "loan.approved", event);
    }
}

// Event Consumer (in Notification Service)
@RabbitListener(queues = "loan-notifications")
public void handleLoanApproved(LoanApprovedEvent event) {
    notificationService.sendLoanApprovalNotification(event);
}
```

## Database Per Service

Each service has its own database:

| Service | Database | Port |
|---------|----------|------|
| Auth Service | auth_db | 5433 |
| User Service | user_db | 5434 |
| Loan Service | loan_db | 5435 |
| Notification Service | notification_db | 5436 |

## Testing New Services

### Unit Tests

```java
@ExtendWith(MockitoExtension.class)
class LoanServiceTest {
    
    @Mock
    private LoanRepository loanRepository;
    
    @InjectMocks
    private LoanServiceImpl loanService;
    
    @Test
    void shouldApplyForLoan() {
        // Test implementation
    }
}
```

### Integration Tests

```java
@SpringBootTest
@AutoConfigureMockMvc
class LoanControllerIntegrationTest {
    
    @Autowired
    private MockMvc mockMvc;
    
    @Test
    void shouldCreateLoanApplication() throws Exception {
        mockMvc.perform(post("/api/v1/loans/apply")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());
    }
}
```

## Deployment Checklist for New Services

- [ ] Service code implemented and tested
- [ ] Dockerfile created with multi-stage build
- [ ] Helm chart created with all environments
- [ ] Jenkins pipeline configured
- [ ] API Gateway routes added
- [ ] Database provisioned
- [ ] Secrets configured
- [ ] Monitoring dashboards created
- [ ] Documentation updated
- [ ] Security review completed

## Best Practices

1. **Follow existing patterns** - Use the same structure as existing services
2. **Independent deployability** - Each service should be deployable independently
3. **API versioning** - Use `/api/v1/` prefix for all endpoints
4. **Health checks** - Implement `/health` and `/ready` endpoints
5. **Metrics** - Expose Prometheus metrics at `/actuator/prometheus`
6. **Logging** - Use structured JSON logging
7. **Error handling** - Use consistent error response format
8. **Documentation** - Generate OpenAPI specs automatically
