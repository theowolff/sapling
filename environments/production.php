
<?php
    /**
     * Environment configuration for production.
     * Strict; no debug, no edits/installs via wp-admin.
     *
     * @package sapling
     * @author theowolff
     */

    /**
     * Ensure WordPress is loaded before running environment config.
     */
    defined('ABSPATH') || exit;

    /**
     * Disable debugging.
     */
    if(! defined('WP_DEBUG')) {
        define('WP_DEBUG', false);
    }

    /**
     * Don't write to debug log.
     */
    if(! defined('WP_DEBUG_LOG')) {
        define('WP_DEBUG_LOG', false);
    }

    /**
     * Never display debug info.
     */
    if(! defined('WP_DEBUG_DISPLAY')) {
        define('WP_DEBUG_DISPLAY', false);
    }

    /**
     * Hide PHP errors/warnings/notices.
     */
    @ini_set('display_errors', '0');

    /**
     * Hard-disable theme/plugin editor and installs/updates.
     */
    if(! defined('DISALLOW_FILE_EDIT')) {
        define('DISALLOW_FILE_EDIT', true);
    }

    if(! defined('DISALLOW_FILE_MODS')) {
        define('DISALLOW_FILE_MODS', true);
    }

    /**
     * Disable automatic core updates.
     */
    if(! defined('AUTOMATIC_UPDATER_DISABLED')) {
        define('AUTOMATIC_UPDATER_DISABLED', true);
    }
