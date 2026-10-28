<?php

// PHP's built-in server omits QUERY_STRING for requests without a query.
$_SERVER['QUERY_STRING'] ??= '';

// PHP's development server treats URLs containing dots as static files instead
// of falling back to the API entry point.
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if ($path === '/api/v2' || str_starts_with($path, '/api/v2/')) {
    require __DIR__ . '/src/api/v2/index.php';
    return true;
}

return false;
