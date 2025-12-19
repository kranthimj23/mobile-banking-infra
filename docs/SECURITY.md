# Security Documentation

This document outlines the security measures implemented in the Mobile Banking Platform and provides a checklist for security compliance.

## Security Architecture

### Authentication Flow

```
┌─────────┐     ┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Client │────▶│ API Gateway │────▶│ Auth Service │────▶│  Database   │
└─────────┘     └─────────────┘     └──────────────┘     └─────────────┘
     │                │                     │
     │                │                     │
     │  1. Login      │  2. Validate        │  3. Verify
     │  Request       │  & Forward          │  Credentials
     │                │                     │
     │                │                     │
     │◀───────────────│◀────────────────────│
     │  6. JWT Token  │  5. Generate        │  4. User Found
     │                │  Token              │
```

### Token Structure

**Access Token (JWT):**
- Algorithm: HS256
- Expiration: 1 hour
- Claims: userId, email, roles, issuedAt, expiration

**Refresh Token:**
- Stored in database with user association
- Expiration: 7 days
- Single-use with rotation

## Security Implementations

### Password Security

**Hashing Algorithm:** bcrypt with strength 12

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);
}
```

**Password Requirements:**
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one digit
- At least one special character

### JWT Token Security

**Token Generation:**
```java
private String generateToken(Map<String, Object> claims, String subject, long expiration) {
    return Jwts.builder()
        .setClaims(claims)
        .setSubject(subject)
        .setIssuedAt(new Date())
        .setExpiration(new Date(System.currentTimeMillis() + expiration))
        .signWith(getSigningKey(), SignatureAlgorithm.HS256)
        .compact();
}
```

**Token Validation:**
- Signature verification
- Expiration check
- Issuer validation
- Blacklist check (for revoked tokens)

### Rate Limiting

**Configuration:**
- 100 requests per minute per user
- Redis-backed token bucket algorithm
- Configurable per endpoint

**Implementation:**
```yaml
spring:
  cloud:
    gateway:
      filter:
        request-rate-limiter:
          redis-rate-limiter:
            replenish-rate: 100
            burst-capacity: 100
            requested-tokens: 1
```

### Input Validation

**Request Validation:**
```java
@PostMapping("/register")
public ResponseEntity<?> register(@Valid @RequestBody RegisterRequest request) {
    // Validation annotations handle input validation
}
```

**SQL Injection Prevention:**
- JPA/Hibernate parameterized queries
- No raw SQL concatenation
- Input sanitization

### Network Security

**TLS Configuration:**
- TLS 1.2+ required
- Strong cipher suites only
- Certificate validation

**Network Policies:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: auth-service-network-policy
spec:
  podSelector:
    matchLabels:
      app: auth-service
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: api-gateway
      ports:
        - protocol: TCP
          port: 8081
```

### Secrets Management

**Kubernetes Secrets:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: auth-service-secrets
type: Opaque
data:
  jwt-secret: <base64-encoded-secret>
  db-password: <base64-encoded-password>
```

**Best Practices:**
- Never commit secrets to version control
- Use external secret management (Vault, AWS Secrets Manager)
- Rotate secrets regularly
- Encrypt secrets at rest

## Security Checklist

### Authentication & Authorization

- [x] JWT-based authentication implemented
- [x] Refresh token rotation enabled
- [x] Password hashing with bcrypt (strength 12)
- [x] Password complexity requirements enforced
- [x] Token blacklisting on logout
- [x] Role-based access control (RBAC)
- [ ] Multi-factor authentication (future)
- [ ] OAuth2 provider integration (future)

### API Security

- [x] Rate limiting (100 req/min)
- [x] Input validation on all endpoints
- [x] SQL injection prevention
- [x] XSS prevention (React Native handles this)
- [x] CORS configuration
- [x] Request size limits
- [x] Timeout configuration

### Network Security

- [x] TLS termination at ingress
- [x] Network policies for pod isolation
- [x] Internal service communication secured
- [x] No public database access
- [ ] mTLS between services (future)
- [ ] Web Application Firewall (future)

### Data Security

- [x] Passwords hashed (never stored plain)
- [x] Sensitive data encrypted at rest
- [x] PII handling compliance
- [x] Audit logging enabled
- [ ] Data masking in logs (partial)
- [ ] GDPR compliance features (future)

### Infrastructure Security

- [x] Kubernetes RBAC configured
- [x] Pod security contexts (non-root)
- [x] Read-only root filesystem
- [x] Resource limits defined
- [x] Network policies enabled
- [x] Secrets encrypted at rest
- [ ] Pod Security Policies/Standards (future)
- [ ] Image scanning in CI/CD (future)

### Monitoring & Incident Response

- [x] Health check endpoints
- [x] Prometheus metrics
- [x] Centralized logging
- [x] Distributed tracing
- [ ] Security event alerting (future)
- [ ] Incident response runbooks (future)

## Security Headers

The API Gateway adds the following security headers:

```yaml
spring:
  cloud:
    gateway:
      default-filters:
        - AddResponseHeader=X-Content-Type-Options, nosniff
        - AddResponseHeader=X-Frame-Options, DENY
        - AddResponseHeader=X-XSS-Protection, 1; mode=block
        - AddResponseHeader=Strict-Transport-Security, max-age=31536000; includeSubDomains
```

## Vulnerability Management

### Dependency Scanning

Run dependency vulnerability checks:
```bash
# Maven
./mvnw dependency-check:check

# npm
npm audit
```

### Container Scanning

Scan Docker images for vulnerabilities:
```bash
# Using Trivy
trivy image mobile-banking/auth-service:latest
```

### Penetration Testing

Recommended tools:
- OWASP ZAP for API testing
- Burp Suite for comprehensive testing
- SQLMap for SQL injection testing

## Incident Response

### Security Incident Procedure

1. **Detection** - Monitor alerts and logs
2. **Containment** - Isolate affected systems
3. **Investigation** - Analyze logs and traces
4. **Eradication** - Remove threat
5. **Recovery** - Restore services
6. **Lessons Learned** - Document and improve

### Emergency Contacts

| Role | Contact |
|------|---------|
| Security Lead | security@example.com |
| On-Call Engineer | oncall@example.com |
| Incident Manager | incidents@example.com |

## Compliance

### Regulatory Requirements

| Regulation | Status | Notes |
|------------|--------|-------|
| PCI DSS | Partial | Card data not stored |
| GDPR | Partial | Data handling in place |
| SOC 2 | Planned | Audit scheduled |

### Audit Logging

All security-relevant events are logged:
- Authentication attempts (success/failure)
- Authorization decisions
- Password changes
- Token refresh/revocation
- Admin actions

## Security Updates

### Update Procedure

1. Monitor security advisories
2. Test updates in staging
3. Apply updates during maintenance window
4. Verify system functionality
5. Document changes

### Patch Management

- Critical patches: Within 24 hours
- High severity: Within 7 days
- Medium severity: Within 30 days
- Low severity: Next release cycle
