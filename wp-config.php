<?php 
    use Dotenv\Dotenv;

    // Get the autoload file from Composer
    require_once __DIR__ . '/vendor/autoload.php';

    // Load .env file
    $env = Dotenv::createImmutable(__DIR__);
    $env->load();

    // ** MySQL settings - You can get this info from your web host ** //
    // The name of the database for WordPress
    define('DB_NAME', $_ENV['DB_NAME'] ?? 'wordpress');
    define('DB_USER', $_ENV['DB_USER'] ?? 'root');
    define('DB_PASSWORD', $_ENV['DB_PASSWORD'] ?? '');
    define('DB_HOST', $_ENV['DB_HOST'] ?? 'localhost');
    $table_prefix = $_ENV['TABLE_PREFIX'] ?? 'wp_';

    // Theme slug and default URL
    $slug = $_ENV['CHILD_THEME_SLUG'] ?? 'sapling-child';
    $def = 'http://' . $slug . '.localhost:8080';

    // Wordpress URL settings
    define('WP_HOME', $_ENV['WP_HOME'] ?? $def);
    define('WP_SITEURL', $_ENV['WP_SITEURL'] ?? WP_HOME . '/wp');

    // Content directory settings
    define('CONTENT_DIR', '/wp-content');
    define('WP_CONTENT_DIR', __DIR__ . CONTENT_DIR);
    define('WP_CONTENT_URL', WP_HOME . CONTENT_DIR);

    // WP memory defaults
    if(! function_exists('splng_set_memory_defaults')) {

        function splng_set_memory_defaults($default = '128M', $max = '512M') {

            if(! defined('WP_MEMORY_LIMIT')) {
                $memory_env_val = $_ENV['WP_MEMORY_LIMIT'] ?? $_SERVER['WP_MEMORY_LIMIT'] ?? null;
                define('WP_MEMORY_LIMIT', $memory_env_val ?: $default);
            }

            if(! defined('WP_MAX_MEMORY_LIMIT')) {
                $memory_env_val = $_ENV['WP_MAX_MEMORY_LIMIT'] ?? $_SERVER['WP_MAX_MEMORY_LIMIT'] ?? null;
                define('WP_MAX_MEMORY_LIMIT', $memory_env_val ?: $max);
            }
        }
    }

    splng_set_memory_defaults('128M', '256M');

    // Environment-specific additional settings
    $env_type = $_ENV['WP_ENV'] ?? 'development';
    $env_config = __DIR__ . '/environments/' . $env_type . '.php';

    // Require the relevant environment file
    if(file_exists($env_config)) {
        require_once $env_config;
    } else {
        // Fallback if missing
        require_once __DIR__ . '/environments/development.php';
    }

    // Define ABSPATH and require the WordPress settings file
    if (! defined('ABSPATH')) {
        define('ABSPATH', __DIR__ . '/wp/');
    }

    require_once ABSPATH . 'wp-settings.php';
