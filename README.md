![Sapling Logo](./sapling.svg)
# Sapling

This repository manages the full WordPress stack (core, parent + child themes, plugins) using Docker, Composer, and WP-CLI.

Sapling supports two modes:
- **Traditional** — Full WordPress with server-rendered themes (sapling-theme)
- **Headless** — API-only WordPress with JWT authentication (stump-theme)

---

## Configuration

All key settings are defined in `.env`:

### Core Settings

| Variable | Description |
|----------|-------------|
| `IS_HEADLESS` | Set to `true` for headless/API mode (Stump), leave empty for traditional (Sapling) |
| `CHILD_THEME_SLUG` | Folder name & text domain for the child theme |
| `CHILD_THEME_NAME` | Display name for the child theme |
| `ADMIN_USER` | Admin username |
| `ADMIN_EMAIL` | Admin email address |
| `ADMIN_PASSWORD` | If empty, a strong password is auto-generated and stored in `.admin_pass` |
| `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST` | Database connection |
| `TABLE_PREFIX` | DB table prefix (default: `splng_`) |
| `WP_HOME` | Site URL (defaults to `http://<CHILD_THEME_SLUG>.localhost:8080`) |

### Headless Mode Settings (Stump)

These are only used when `IS_HEADLESS=true`:

| Variable | Description |
|----------|-------------|
| `STMP_JWT_SECRET` | **Required** — Secret key for JWT signing. Generate with: `openssl rand -base64 32` |
| `STMP_JWT_EXPIRATION` | Token lifetime in seconds (default: `3600` = 1 hour) |
| `STMP_API_DEBUG` | Enable API request logging (default: `false`) |
| `STMP_CORS_ORIGINS` | Comma-separated allowed CORS origins |

---

## Quick Start

### Traditional Mode (Sapling)

```bash
cp .env.example .env
# Edit .env: leave IS_HEADLESS empty or remove it
chmod +x scripts/*.sh
./scripts/setup.sh
```

### Headless Mode (Stump)

```bash
cp .env.example .env
# Edit .env: set IS_HEADLESS=true and STMP_JWT_SECRET
chmod +x scripts/*.sh
./scripts/setup.sh
```

This will:
1. Spin up Docker containers (PHP, MySQL, Adminer)
2. Install WordPress + required plugins via Composer
3. Clone and build the appropriate parent + child themes
4. Inject fresh WordPress salts (and Stump API config if headless)
5. Set up the admin user and activate the child theme

---

## Development Workflow

- **Start stack**
  ```bash
  docker compose up -d
  ```

- **Watch assets** (traditional mode only)
  ```bash
  ./scripts/dev.sh
  ```

- **Production build** (traditional mode only)
  ```bash
  ./scripts/build.sh
  ```

- **Access container shell**
  ```bash
  ./scripts/ssh.sh
  ```

- **Regenerate salts**
  ```bash
  ./scripts/salts.sh
  ```

---

## Important URLs

### Traditional Mode
- WordPress: [http://localhost:8080](http://localhost:8080)
- Admin dashboard: [http://localhost:8080/wp-admin](http://localhost:8080/wp-admin)
- Adminer (DB GUI): [http://localhost:8081](http://localhost:8081)

### Headless Mode (Stump API)
- Health check: `GET /wp-json/stump/v1/health`
- Login: `POST /wp-json/stump/v1/auth/login`
- Refresh token: `POST /wp-json/stump/v1/auth/refresh`
- Logout: `POST /wp-json/stump/v1/auth/logout`
- Current user: `GET /wp-json/stump/v1/user/me`
- Menus: `GET /wp-json/stump/v1/menus`
- Settings: `GET /wp-json/stump/v1/settings`

If `WP_HOME` is set in `.env`, replace `localhost:8080` with your chosen domain.

---

## Headless Mode (Stump) Details

### Authentication

Stump uses JWT (JSON Web Tokens) for stateless authentication.

**Login:**
```bash
curl -X POST http://localhost:8080/wp-json/stump/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "your-password"}'
```

**Response:**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "email": "admin@example.com",
      "display_name": "Admin"
    },
    "expires_at": 1234567890
  }
}
```

**Using the token:**
```bash
curl http://localhost:8080/wp-json/stump/v1/user/me \
  -H "Authorization: Bearer <your-token>"
```

### Extending the API

Custom endpoints can be added in the child theme:

```php
// In child theme's extras/theme-functions.php
add_action('STMP_register_endpoints', function($router) {
    $router->register(new My_Custom_Endpoint());
});
```

See the [Stump documentation](https://github.com/theowolff/stump-theme) for full API reference.

---

## Deployment

### Prerequisites
- Docker installed on target server
- `.env` configured with production values (strong DB password, real domain, etc.)
- For headless: Strong `STMP_JWT_SECRET` generated

### Steps
1. **Clone the repo** onto your server:
   ```bash
   git clone git@github.com:YOUR_ORG/sapling.git
   cd sapling
   cp .env.example .env
   # edit .env with production values
   ```

2. **Build and run stack**:
   ```bash
   chmod +x scripts/*.sh
   ./scripts/setup.sh
   ```

3. **Point DNS** of your production domain to the server.

4. **Update `WP_HOME` and `WP_SITEURL`** in `.env` (match your production domain).

5. **Restart services**:
   ```bash
   docker compose down
   docker compose up -d
   ```

### Remote Deployment Workflow

For deploying to a remote Docker server (staging/production):

```bash
# Copy files to server
scp -r . user@server:/var/www/sapling

# SSH into server
ssh user@server

# Inside server
cd /var/www/sapling
cp .env.example .env
# edit .env for production
chmod +x scripts/*.sh
./scripts/setup.sh
```

When updating:
```bash
git pull origin main
./scripts/build.sh  # traditional mode only
docker compose down
docker compose up -d
```

---

## Security Notes

- Salts/keys in `wp-config.php` are auto-generated via [WordPress.org API](https://api.wordpress.org/secret-key/1.1/salt/)
- Re-run `./scripts/salts.sh` anytime to rotate keys (forces all users to log in again)
- Avoid committing real salts, passwords, or DB credentials to version control
- **Headless mode**: Use a strong, unique `STMP_JWT_SECRET` — never use defaults

---

## Theme Repositories

| Mode | Parent Theme | Child Theme Template |
|------|--------------|---------------------|
| Traditional | [sapling-theme](https://github.com/theowolff/sapling-theme) | [sapling-theme-child](https://github.com/theowolff/sapling-theme-child) |
| Headless | [stump-theme](https://github.com/theowolff/stump-theme) | [stump-theme-child](https://github.com/theowolff/stump-theme-child) |

---

## References

- [WordPress.org Documentation](https://wordpress.org/support/)
- [WP-CLI Commands](https://developer.wordpress.org/cli/commands/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Stump API Documentation](https://github.com/theowolff/stump-theme)