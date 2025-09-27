
<?php
    /**
     * Main WordPress configuration file for Sapling local dev.
     *
     * @package sapling
     * @author theowolff
     */

    use Dotenv\Dotenv;

    /**
     * Composer autoload and .env loading
     */
    require_once __DIR__ . '/vendor/autoload.php';
    $env = Dotenv::createImmutable(__DIR__);
    $env->load();

    /**
     * MySQL and database settings
     */
    define('DB_NAME', $_ENV['DB_NAME'] ?? 'wordpress');
    define('DB_USER', $_ENV['DB_USER'] ?? 'root');
    define('DB_PASSWORD', $_ENV['DB_PASSWORD'] ?? '');
    define('DB_HOST', $_ENV['DB_HOST'] ?? 'localhost');
    $table_prefix = $_ENV['TABLE_PREFIX'] ?? 'wp_';

    /**
     * Theme slug and default URL
     */
    $slug = $_ENV['CHILD_THEME_SLUG'] ?? 'sapling-child';
    $def = 'http://' . $slug . '.localhost:8080';

    /**
     * WordPress URL settings
     */
    define('WP_HOME', $_ENV['WP_HOME'] ?? $def);
    define('WP_SITEURL', $_ENV['WP_SITEURL'] ?? WP_HOME . '/wp');

    /**
     * Content directory settings
     */
    define('CONTENT_DIR', '/wp-content');
    define('WP_CONTENT_DIR', __DIR__ . CONTENT_DIR);
    define('WP_CONTENT_URL', WP_HOME . CONTENT_DIR);

    /**
     * Set WP memory defaults
     * @param string $default
     * @param string $max
     * @return void
     */
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

    /**
     * Load environment-specific additional settings
     */
    $env_type = $_ENV['WP_ENV'] ?? 'development';
    $env_config = __DIR__ . '/environments/' . $env_type . '.php';

    // Require the relevant environment file
    if(file_exists($env_config)) {
        require_once $env_config;
    } else {
        // Fallback if missing
        require_once __DIR__ . '/environments/development.php';
    }

    /**
     * Define ABSPATH and require the WordPress settings file
     */
    if (! defined('ABSPATH')) {
        define('ABSPATH', __DIR__ . '/wp/');
    }
    require_once ABSPATH . 'wp-settings.php';
