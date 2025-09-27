# twwp-core

This repository manages the full WordPress stack (core, parent + child themes, plugins) using Docker, Composer, and WP-CLI.  
It pulls in **twwp-theme** (parent) and **twwp-theme-child** (child), builds both asset pipelines, and activates the child theme automatically.

---

## 🔧 Configuration

All key settings are defined in `.env`:

- `CHILD_THEME_SLUG` → folder name & text domain for the child theme  
- `CHILD_THEME_NAME` → display name for the child theme  
- `ADMIN_USER` → admin username  
- `ADMIN_EMAIL` → admin email address  
- `ADMIN_PASSWORD` (optional) → if empty, a strong password is auto-generated and stored in `.admin_pass`  
- `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST` → database connection  
- `TABLE_PREFIX` → DB table prefix (default: `wp_`)  
- `WP_HOME` → site URL (defaults to `http://<CHILD_THEME_SLUG>.localhost:8080`)  

---

## 🚀 Quick Start (Development)

```bash
cp .env.example .env
# edit variables as needed
chmod +x scripts/*.sh
./scripts/setup.sh
```

This will:
1. Spin up Docker containers (PHP, MySQL, Adminer).
2. Install WordPress + required plugins via Composer.
3. Clone and build the parent + child themes.
4. Inject fresh WordPress salts into `wp-config.php`.
5. Set up the admin user and activate the child theme.

---

## 📦 Development Workflow

- **Start stack**  
  ```bash
  docker compose up -d
  ```

- **Watch assets**  
  ```bash
  ./scripts/dev.sh
  ```

- **Production build**  
  ```bash
  ./scripts/build.sh
  ```

- **Access container shell**  
  ```bash
  ./scripts/ssh.sh
  ```

- **Regenerate salts**  
  ```bash
  ./scripts/generate-salts.sh
  ```

---

## 🌐 Important URLs

- WordPress: [http://localhost:8080](http://localhost:8080)  
- Admin dashboard: [http://localhost:8080/wp-admin](http://localhost:8080/wp-admin)  
- Adminer (DB GUI): [http://localhost:8081](http://localhost:8081)  

If `WP_HOME` is set in `.env`, replace `localhost:8080` with your chosen domain.

---

## 📤 Deployment

### Prerequisites
- Docker installed on target server
- `.env` configured with production values (strong DB password, real domain, etc.)
- Volume mounts or external DB configured if persistence is required

### Steps
1. **Clone the repo** onto your server:
   ```bash
   git clone git@github.com:YOUR_ORG/twwp-core.git
   cd twwp-core
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
scp -r . user@server:/var/www/twwp-core

# SSH into server
ssh user@server

# Inside server
cd /var/www/twwp-core
cp .env.example .env
# edit .env for production (set domain, DB creds, salts will be generated)
chmod +x scripts/*.sh
./scripts/setup.sh
```

When updating:
```bash
git pull origin main
./scripts/build.sh
docker compose down
docker compose up -d
```

---

## 🗝 Security Notes
- Salts/keys in `wp-config.php` are auto-generated via [WordPress.org API](https://api.wordpress.org/secret-key/1.1/salt/).  
- Re-run `./scripts/generate-salts.sh` anytime to rotate keys (forces all users to log in again).  
- Avoid committing real salts, passwords, or DB credentials to version control.  

---

## 📚 References
- [WordPress.org Documentation](https://wordpress.org/support/)  
- [WP-CLI Commands](https://developer.wordpress.org/cli/commands/)  
- [Docker Compose](https://docs.docker.com/compose/)  

---
