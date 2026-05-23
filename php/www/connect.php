<?php
$host     = getenv('DB_HOST')     ?: 'db';
$username = getenv('DB_USER')     ?: 'root';
$password = getenv('DB_PASSWORD') ?: 'root';
$dbname   = getenv('DB_NAME')     ?: 'gestion_produits';

$db = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username, $password);
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
?>
