# Authentication & Authorization

Raxol provides a comprehensive authentication and authorization system for securing terminal applications in enterprise environments.

## Overview

The authentication system supports multiple providers and can be customized to integrate with existing enterprise identity management systems.

## Authentication Providers

### Database Authentication

Built-in user management with secure password storage:

```elixir
config :raxol, :auth,
  provider: :database,
  password_policy: [
    min_length: 12,
    require_uppercase: true,
    require_lowercase: true,
    require_numbers: true,
    require_special: true
  ]
```

### LDAP/Active Directory

```elixir
config :raxol, :auth,
  provider: :ldap,
  ldap: [
    host: "ldap.company.com",
    port: 636,
    ssl: true,
    base_dn: "dc=company,dc=com",
    user_dn_pattern: "uid={username},ou=users,dc=company,dc=com",
    group_base_dn: "ou=groups,dc=company,dc=com"
  ]
```

### OAuth 2.0 / OpenID Connect

```elixir
config :raxol, :auth,
  provider: :oauth2,
  oauth2: [
    client_id: "raxol-app",
    client_secret: {:system, "OAUTH_CLIENT_SECRET"},
    discovery_url: "https://auth.company.com/.well-known/openid-configuration",
    scopes: ["openid", "profile", "email", "groups"]
  ]
```

### SAML 2.0

```elixir
config :raxol, :auth,
  provider: :saml,
  saml: [
    idp_metadata_url: "https://idp.company.com/metadata",
    sp_entity_id: "https://raxol.company.com",
    sp_certificate: {:file, "priv/certs/sp.crt"},
    sp_private_key: {:file, "priv/certs/sp.key"}
  ]
```

## Multi-Factor Authentication (MFA)

### TOTP (Time-based One-Time Password)

```elixir
defmodule MyApp.Auth do
  use Raxol.Enterprise.MFA.TOTP
  
  def setup_mfa(user) do
    secret = generate_secret()
    qr_code = generate_qr_code(user.email, secret)
    
    {:ok, %{
      secret: secret,
      qr_code: qr_code,
      backup_codes: generate_backup_codes()
    }}
  end
  
  def verify_mfa(user, code) do
    verify_totp(user.mfa_secret, code)
  end
end
```

### WebAuthn / FIDO2

```elixir
defmodule MyApp.Auth do
  use Raxol.Enterprise.MFA.WebAuthn
  
  def register_device(user, credential) do
    # Register FIDO2 device
    case verify_credential(credential) do
      {:ok, device} ->
        save_device(user, device)
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

## Role-Based Access Control (RBAC)

### Defining Roles and Permissions

```elixir
defmodule MyApp.Roles do
  use Raxol.Enterprise.RBAC
  
  role :admin do
    can :manage, :all
  end
  
  role :operator do
    can :read, :terminals
    can :execute, :commands
    cannot :delete, :sessions
  end
  
  role :viewer do
    can :read, :terminals
    can :read, :logs
    cannot :execute, :commands
  end
end
```

### Checking Permissions

```elixir
defmodule MyApp.SecureComponent do
  use Raxol.UI.Components.Base.Component
  
  def render(state, context) do
    user = context.current_user
    
    {:box, [],
      [
        if can?(user, :execute, :commands) do
          {:button, [label: "Run Command", on_click: :execute]}
        else
          {:text, [color: :gray], "No permission to execute commands"}
        end
      ]
    }
  end
end
```

## Session Management

### Session Configuration

```elixir
config :raxol, :sessions,
  store: :redis,  # or :ets, :database
  ttl: 3600,      # 1 hour
  max_concurrent: 3,
  idle_timeout: 900,  # 15 minutes
  secure_cookies: true,
  same_site: :strict
```

### Session Lifecycle

```elixir
defmodule MyApp.SessionManager do
  use Raxol.Enterprise.Sessions
  
  def on_login(user, session) do
    # Log login event
    audit_log(:login, user, session)
    
    # Set session data
    put_session(session, :user_id, user.id)
    put_session(session, :roles, user.roles)
    put_session(session, :login_time, DateTime.utc_now())
  end
  
  def on_logout(user, session) do
    # Clean up resources
    terminate_user_processes(user)
    
    # Log logout event
    audit_log(:logout, user, session)
    
    # Clear session
    clear_session(session)
  end
end
```

## Security Headers

Automatically set security headers for web access:

```elixir
defmodule MyAppWeb.SecurityPlug do
  use Raxol.Enterprise.Security.Headers
  
  headers [
    "X-Frame-Options": "DENY",
    "X-Content-Type-Options": "nosniff",
    "X-XSS-Protection": "1; mode=block",
    "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
    "Content-Security-Policy": "default-src 'self'",
    "Referrer-Policy": "strict-origin-when-cross-origin"
  ]
end
```

## Audit Logging

Track all authentication events:

```elixir
defmodule MyApp.AuditLog do
  use Raxol.Enterprise.Audit
  
  def log_auth_event(event, user, details) do
    audit(:authentication, %{
      event: event,
      user_id: user.id,
      username: user.username,
      ip_address: details.ip,
      user_agent: details.user_agent,
      timestamp: DateTime.utc_now(),
      success: details.success,
      reason: details.reason
    })
  end
end
```

## API Authentication

For programmatic access:

### API Keys

```elixir
defmodule MyApp.APIAuth do
  use Raxol.Enterprise.APIKeys
  
  def generate_api_key(user, scopes) do
    key = generate_secure_key()
    
    save_api_key(%{
      key_hash: hash_key(key),
      user_id: user.id,
      scopes: scopes,
      expires_at: DateTime.add(DateTime.utc_now(), 365, :day)
    })
    
    {:ok, key}
  end
  
  def verify_api_key(key) do
    case lookup_key(hash_key(key)) do
      {:ok, api_key} ->
        if DateTime.compare(api_key.expires_at, DateTime.utc_now()) == :gt do
          {:ok, api_key}
        else
          {:error, :expired}
        end
      :error ->
        {:error, :invalid}
    end
  end
end
```

### JWT Tokens

```elixir
defmodule MyApp.JWTAuth do
  use Raxol.Enterprise.JWT
  
  def generate_token(user) do
    claims = %{
      "sub" => user.id,
      "email" => user.email,
      "roles" => user.roles,
      "exp" => :os.system_time(:second) + 3600
    }
    
    sign_token(claims)
  end
  
  def verify_token(token) do
    case decode_and_verify(token) do
      {:ok, claims} ->
        if claims["exp"] > :os.system_time(:second) do
          {:ok, claims}
        else
          {:error, :expired}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

## Best Practices

1. **Use Strong Authentication**: Always use MFA for privileged accounts
2. **Principle of Least Privilege**: Grant minimum necessary permissions
3. **Regular Audits**: Review authentication logs regularly
4. **Session Security**: Use secure cookies and implement idle timeouts
5. **Password Policies**: Enforce strong password requirements
6. **API Security**: Use time-limited tokens and rotate API keys
7. **Monitor Failed Attempts**: Implement account lockout policies

## Troubleshooting

### Common Issues

1. **LDAP Connection Failures**
   ```elixir
   # Test LDAP connectivity
   Raxol.Enterprise.Auth.LDAP.test_connection()
   ```

2. **Session Timeout Issues**
   ```elixir
   # Check session configuration
   Raxol.Enterprise.Sessions.get_config()
   ```

3. **MFA Setup Problems**
   ```elixir
   # Verify MFA configuration
   Raxol.Enterprise.MFA.verify_setup()
   ```

## Next Steps

- Configure [Monitoring](monitoring.md) for authentication events
- Set up [Security](security.md) policies
- Plan [Deployment](deployment.md) with authentication infrastructure