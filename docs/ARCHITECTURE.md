# Mobile Banking Application - Architecture Documentation

## C4 Model Architecture

### Level 1: System Context Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MOBILE BANKING SYSTEM                              │
│                                                                              │
│  ┌──────────────┐                                                           │
│  │   Mobile     │                                                           │
│  │   User       │◄──────────────────────────────────────────────────────┐   │
│  │              │                                                       │   │
│  └──────┬───────┘                                                       │   │
│         │                                                               │   │
│         │ HTTPS/TLS                                                     │   │
│         ▼                                                               │   │
│  ┌──────────────────────────────────────────────────────────────────┐  │   │
│  │                    MOBILE BANKING PLATFORM                        │  │   │
│  │                                                                   │  │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │  │   │
│  │  │   Auth      │  │   User      │  │   API       │              │  │   │
│  │  │   Service   │  │   Service   │  │   Gateway   │◄─────────────┼──┘   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘              │      │
│  │                                                                   │      │
│  │  ┌─────────────┐  ┌─────────────┐  (Future Services)            │      │
│  │  │   Loan      │  │ Notification│                                │      │
│  │  │   Service   │  │   Service   │                                │      │
│  │  └─────────────┘  └─────────────┘                                │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐                                        │
│  │   OAuth2     │  │   External   │                                        │
│  │   Provider   │  │   Services   │                                        │
│  │  (Google,    │  │   (SMS,      │                                        │
│  │   GitHub)    │  │   Email)     │                                        │
│  └──────────────┘  └──────────────┘                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Level 2: Container Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              KUBERNETES CLUSTER (GKE/EKS)                            │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                              INGRESS CONTROLLER                              │   │
│  │                         (NGINX with TLS Termination)                         │   │
│  └─────────────────────────────────────┬───────────────────────────────────────┘   │
│                                        │                                            │
│                                        ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                              API GATEWAY                                     │   │
│  │                                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │   │
│  │  │   Request    │  │    Auth      │  │    Rate      │  │   Request    │   │   │
│  │  │   Routing    │  │  Enforcement │  │   Limiting   │  │   Logging    │   │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │   │
│  │                                                                              │   │
│  │  Port: 8080 | Service: LoadBalancer | HPA: 2-10 replicas                    │   │
│  └─────────────────────────────────────┬───────────────────────────────────────┘   │
│                                        │                                            │
│         ┌──────────────────────────────┼──────────────────────────────┐            │
│         │                              │                              │            │
│         ▼                              ▼                              ▼            │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐                 │
│  │   AUTH SERVICE   │  │   USER SERVICE   │  │  FUTURE SERVICES │                 │
│  │                  │  │                  │  │                  │                 │
│  │  ┌────────────┐  │  │  ┌────────────┐  │  │  ┌────────────┐  │                 │
│  │  │ JWT Token  │  │  │  │ User CRUD  │  │  │  │   Loan     │  │                 │
│  │  │ Generation │  │  │  │ Operations │  │  │  │  Service   │  │                 │
│  │  └────────────┘  │  │  └────────────┘  │  │  └────────────┘  │                 │
│  │  ┌────────────┐  │  │  ┌────────────┐  │  │  ┌────────────┐  │                 │
│  │  │   OAuth2   │  │  │  │  Profile   │  │  │  │Notification│  │                 │
│  │  │Integration │  │  │  │ Management │  │  │  │  Service   │  │                 │
│  │  └────────────┘  │  │  └────────────┘  │  │  └────────────┘  │                 │
│  │  ┌────────────┐  │  │  ┌────────────┐  │  │                  │                 │
│  │  │  Refresh   │  │  │  │   Status   │  │  │                  │                 │
│  │  │   Token    │  │  │  │  Tracking  │  │  │                  │                 │
│  │  └────────────┘  │  │  └────────────┘  │  │                  │                 │
│  │                  │  │                  │  │                  │                 │
│  │  Port: 8081     │  │  Port: 8082     │  │  Ports: 8083+    │                 │
│  │  ClusterIP      │  │  ClusterIP      │  │  ClusterIP       │                 │
│  │  HPA: 2-5       │  │  HPA: 2-5       │  │  HPA: 2-5        │                 │
│  └────────┬─────────┘  └────────┬─────────┘  └──────────────────┘                 │
│           │                     │                                                  │
│           ▼                     ▼                                                  │
│  ┌──────────────────┐  ┌──────────────────┐                                       │
│  │   AUTH DATABASE  │  │   USER DATABASE  │                                       │
│  │   (PostgreSQL)   │  │   (PostgreSQL)   │                                       │
│  │                  │  │                  │                                       │
│  │  - users_auth    │  │  - users         │                                       │
│  │  - refresh_tokens│  │  - user_profiles │                                       │
│  │  - oauth_tokens  │  │  - user_status   │                                       │
│  │                  │  │                  │                                       │
│  │  PVC: 10Gi       │  │  PVC: 10Gi       │                                       │
│  └──────────────────┘  └──────────────────┘                                       │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           OBSERVABILITY STACK                                │   │
│  │                                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │   │
│  │  │  Prometheus  │  │   Grafana    │  │ Elasticsearch│  │    Jaeger    │   │   │
│  │  │   Metrics    │  │  Dashboards  │  │   Logging    │  │   Tracing    │   │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Level 3: Component Diagram - Auth Service

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AUTH SERVICE                                    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         REST CONTROLLERS                             │   │
│  │                                                                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │  │AuthController│  │TokenController│  │OAuth2Controller│            │   │
│  │  │              │  │              │  │              │              │   │
│  │  │ POST /login  │  │POST /refresh │  │GET /oauth2/  │              │   │
│  │  │ POST /logout │  │POST /revoke  │  │   authorize  │              │   │
│  │  │ POST /register│ │GET /validate │  │POST /oauth2/ │              │   │
│  │  └──────┬───────┘  └──────┬───────┘  │   callback   │              │   │
│  │         │                 │          └──────┬───────┘              │   │
│  └─────────┼─────────────────┼─────────────────┼───────────────────────┘   │
│            │                 │                 │                            │
│            ▼                 ▼                 ▼                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         SERVICE LAYER                                │   │
│  │                                                                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │  │AuthService   │  │TokenService  │  │OAuth2Service │              │   │
│  │  │              │  │              │  │              │              │   │
│  │  │- authenticate│  │- generateJWT │  │- handleGoogle│              │   │
│  │  │- validatePwd │  │- refreshToken│  │- handleGitHub│              │   │
│  │  │- hashPassword│  │- revokeToken │  │- linkAccount │              │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │   │
│  └─────────┼─────────────────┼─────────────────┼───────────────────────┘   │
│            │                 │                 │                            │
│            ▼                 ▼                 ▼                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       REPOSITORY LAYER                               │   │
│  │                                                                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │  │UserAuthRepo  │  │RefreshToken  │  │OAuthTokenRepo│              │   │
│  │  │              │  │    Repo      │  │              │              │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      SECURITY COMPONENTS                             │   │
│  │                                                                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │  │JwtTokenUtil  │  │PasswordEncoder│ │SecurityConfig│              │   │
│  │  │              │  │   (BCrypt)   │  │              │              │   │
│  │  │- generate    │  │              │  │- CORS config │              │   │
│  │  │- validate    │  │- encode      │  │- Auth rules  │              │   │
│  │  │- extractClaims│ │- matches     │  │- Filters     │              │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Level 3: Component Diagram - User Service

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER SERVICE                                    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         REST CONTROLLERS                             │   │
│  │                                                                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │  │UserController│  │ProfileController│ │StatusController│           │   │
│  │  │              │  │              │  │              │              │   │
│  │  │ GET /users   │  │GET /profile  │  │GET /status   │              │   │
│  │  │ GET /users/{id}││PUT /profile  │  │PUT /status   │              │   │
│  │  │ PUT /users/{id}││POST /profile/│  │GET /status/  │              │   │
│  │  │DELETE /users/│ │    avatar    │  │   history    │              │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │   │
│  └─────────┼─────────────────┼─────────────────┼───────────────────────┘   │
│            │                 │                 │                            │
│            ▼                 ▼                 ▼                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         SERVICE LAYER                                │   │
│  │                                                                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │  │UserService   │  │ProfileService│  │StatusService │              │   │
│  │  │              │  │              │  │              │              │   │
│  │  │- createUser  │  │- getProfile  │  │- getStatus   │              │   │
│  │  │- getUser     │  │- updateProfile│ │- updateStatus│              │   │
│  │  │- updateUser  │  │- uploadAvatar│  │- getHistory  │              │   │
│  │  │- deleteUser  │  │              │  │              │              │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │   │
│  └─────────┼─────────────────┼─────────────────┼───────────────────────┘   │
│            │                 │                 │                            │
│            ▼                 ▼                 ▼                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       REPOSITORY LAYER                               │   │
│  │                                                                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │  │UserRepository│  │ProfileRepo   │  │StatusRepo    │              │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      VALIDATION & EVENTS                             │   │
│  │                                                                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │  │InputValidator│  │EventPublisher│  │AuditLogger   │              │   │
│  │  │              │  │              │  │              │              │   │
│  │  │- validateEmail│ │- userCreated │  │- logChange   │              │   │
│  │  │- validatePhone│ │- userUpdated │  │- logAccess   │              │   │
│  │  │- sanitizeInput│ │- statusChanged│ │              │              │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Deployment Topology

### Multi-Cloud Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              MULTI-CLOUD DEPLOYMENT                                  │
│                                                                                      │
│  ┌───────────────────────────────────┐  ┌───────────────────────────────────┐      │
│  │         GOOGLE CLOUD (GKE)        │  │          AWS (EKS)                │      │
│  │                                   │  │                                   │      │
│  │  ┌─────────────────────────────┐  │  │  ┌─────────────────────────────┐  │      │
│  │  │     GKE Cluster             │  │  │  │     EKS Cluster             │  │      │
│  │  │                             │  │  │  │                             │  │      │
│  │  │  ┌───────────────────────┐  │  │  │  │  ┌───────────────────────┐  │  │      │
│  │  │  │   Node Pool: apps     │  │  │  │  │  │   Node Group: apps    │  │  │      │
│  │  │  │   (n1-standard-2)     │  │  │  │  │  │   (t3.medium)         │  │  │      │
│  │  │  │   Min: 2, Max: 10     │  │  │  │  │  │   Min: 2, Max: 10     │  │  │      │
│  │  │  └───────────────────────┘  │  │  │  │  └───────────────────────┘  │  │      │
│  │  │                             │  │  │  │                             │  │      │
│  │  │  ┌───────────────────────┐  │  │  │  │  ┌───────────────────────┐  │  │      │
│  │  │  │   Node Pool: system   │  │  │  │  │  │   Node Group: system  │  │  │      │
│  │  │  │   (n1-standard-2)     │  │  │  │  │  │   (t3.medium)         │  │  │      │
│  │  │  │   Min: 1, Max: 3      │  │  │  │  │  │   Min: 1, Max: 3      │  │  │      │
│  │  │  └───────────────────────┘  │  │  │  │  └───────────────────────┘  │  │      │
│  │  └─────────────────────────────┘  │  │  └─────────────────────────────┘  │      │
│  │                                   │  │                                   │      │
│  │  ┌─────────────────────────────┐  │  │  ┌─────────────────────────────┐  │      │
│  │  │   Cloud SQL (PostgreSQL)   │  │  │  │   RDS (PostgreSQL)          │  │      │
│  │  │   - High Availability      │  │  │  │   - Multi-AZ                │  │      │
│  │  │   - Automated Backups      │  │  │  │   - Automated Backups       │  │      │
│  │  └─────────────────────────────┘  │  │  └─────────────────────────────┘  │      │
│  │                                   │  │                                   │      │
│  │  ┌─────────────────────────────┐  │  │  ┌─────────────────────────────┐  │      │
│  │  │   GCR (Container Registry) │  │  │  │   ECR (Container Registry)  │  │      │
│  │  └─────────────────────────────┘  │  │  └─────────────────────────────┘  │      │
│  │                                   │  │                                   │      │
│  │  ┌─────────────────────────────┐  │  │  ┌─────────────────────────────┐  │      │
│  │  │   Cloud Load Balancer      │  │  │  │   Application Load Balancer │  │      │
│  │  └─────────────────────────────┘  │  │  └─────────────────────────────┘  │      │
│  └───────────────────────────────────┘  └───────────────────────────────────┘      │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                         SHARED COMPONENTS                                    │   │
│  │                                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │   │
│  │  │   Jenkins    │  │  Docker Hub  │  │   Terraform  │  │  Helm Charts │   │   │
│  │  │   CI/CD      │  │   Registry   │  │    State     │  │   Repository │   │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Service Communication

### Request Flow

```
┌──────────┐     ┌───────────┐     ┌──────────────┐     ┌──────────────┐
│  Mobile  │────▶│  Ingress  │────▶│  API Gateway │────▶│   Service    │
│   App    │     │Controller │     │              │     │  (Auth/User) │
└──────────┘     └───────────┘     └──────────────┘     └──────────────┘
     │                │                   │                    │
     │                │                   │                    │
     │           TLS Termination    JWT Validation       Business Logic
     │                │            Rate Limiting              │
     │                │            Request Routing            │
     │                │                   │                    │
     ▼                ▼                   ▼                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        OBSERVABILITY LAYER                          │
│                                                                     │
│  Metrics ──▶ Prometheus ──▶ Grafana                                │
│  Logs ────▶ Fluentd ─────▶ Elasticsearch ──▶ Kibana               │
│  Traces ──▶ Jaeger Agent ▶ Jaeger Collector ▶ Jaeger UI           │
└─────────────────────────────────────────────────────────────────────┘
```

## Security Architecture

### Authentication Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           AUTHENTICATION FLOW                                 │
│                                                                              │
│  1. LOGIN REQUEST                                                            │
│  ┌──────────┐     ┌──────────────┐     ┌──────────────┐                     │
│  │  Mobile  │────▶│  API Gateway │────▶│ Auth Service │                     │
│  │   App    │     │              │     │              │                     │
│  └──────────┘     └──────────────┘     └──────┬───────┘                     │
│                                               │                              │
│  2. CREDENTIAL VALIDATION                     ▼                              │
│                                        ┌──────────────┐                     │
│                                        │   Validate   │                     │
│                                        │  Credentials │                     │
│                                        │   (BCrypt)   │                     │
│                                        └──────┬───────┘                     │
│                                               │                              │
│  3. TOKEN GENERATION                          ▼                              │
│                                        ┌──────────────┐                     │
│                                        │  Generate    │                     │
│                                        │  JWT Token   │                     │
│                                        │  + Refresh   │                     │
│                                        └──────┬───────┘                     │
│                                               │                              │
│  4. RESPONSE                                  ▼                              │
│  ┌──────────┐     ┌──────────────┐     ┌──────────────┐                     │
│  │  Mobile  │◀────│  API Gateway │◀────│ Auth Service │                     │
│  │   App    │     │              │     │              │                     │
│  └──────────┘     └──────────────┘     └──────────────┘                     │
│                                                                              │
│  JWT Token Structure:                                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ Header: { alg: "RS256", typ: "JWT" }                                │   │
│  │ Payload: { sub: "user_id", roles: [...], exp: timestamp, iat: ... } │   │
│  │ Signature: RSASHA256(base64(header) + "." + base64(payload), key)   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Database Schema Overview

### Auth Database
- `users_auth`: Authentication credentials and metadata
- `refresh_tokens`: JWT refresh token storage with rotation
- `oauth_tokens`: OAuth2 provider tokens

### User Database
- `users`: Core user information
- `user_profiles`: Extended profile data
- `user_status`: User status tracking and history

## Future Service Extension Points

The architecture is designed to easily accommodate:

1. **Loan Service** (Port 8083)
   - Loan application processing
   - Credit scoring integration
   - Payment scheduling

2. **Notification Service** (Port 8084)
   - Push notifications
   - SMS integration
   - Email notifications

Extension requires:
- Copy existing Helm chart template
- Update service-specific values
- Add to API Gateway routing
- Deploy using existing Jenkins pipeline pattern
