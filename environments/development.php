<?php
    // Development:
    // Most permissive - show debug, allow file edits & plugin installs.
    defined('ABSPATH') || exit;

    // Enable debugging
    if( !defined('WP_DEBUG')) {
        define('WP_DEBUG', true);
    }

    // Write to debug log
    if(! defined('WP_DEBUG_LOG')) {
        define('WP_DEBUG_LOG', true);
    }

    // Display the debug info by default
    if(! defined('WP_DEBUG_DISPLAY')) {
        define('WP_DEBUG_DISPLAY', true);
    }
    
    // Display all PHP errors, warnings, notices
    @ini_set('display_errors', '1');

    // Allow theme/plugin editor + installs/updates
    if(! defined('DISALLOW_FILE_EDIT')) {
        define('DISALLOW_FILE_EDIT', false);
    }

    if(! defined('DISALLOW_FILE_MODS')) {
        define('DISALLOW_FILE_MODS', false);
    }

    // Disable script concatenation (to make debugging easier)
    if(! defined('CONCATENATE_SCRIPTS')) {
        define('CONCATENATE_SCRIPTS', false);
    }
