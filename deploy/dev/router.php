<?php
$root    = dirname(__DIR__, 2);
$public  = $root . '/public';
$path    = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$file    = $public . $path;
if ($path !== '/' && is_file($file)) {
    return false;
}
chdir($public);
require $public . '/index.php';
