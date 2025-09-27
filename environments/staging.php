<?php
    // Staging:
    // No debug output; allow installs/updates for QA.
    defined('ABSPATH') || exit;

    // Enable debugging
    if(! defined('WP_DEBUG')) {
        define('WP_DEBUG', true);    
    }

    // Write to debug log
    if(! defined('WP_DEBUG_LOG')) {
        define('WP_DEBUG_LOG', true);
    }

    // Display the debug info only
    // if the ?debug $_GET param is present
    if(! defined('WP_DEBUG_DISPLAY')) {
        define('WP_DEBUG_DISPLAY', isset($_GET['debug']));
    }

    // Hide PHP errors/warnings/notices by default
    @ini_set('display_errors', '0');

    // Allow theme/plugin installs (for testing), 
    // but disable file editor in wp-admin
    if(! defined('DISALLOW_FILE_EDIT')) {
        define('DISALLOW_FILE_EDIT', true);
    }

    if(! defined('DISALLOW_FILE_MODS')) {
        define('DISALLOW_FILE_MODS', false);
    }
