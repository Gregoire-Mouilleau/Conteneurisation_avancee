<?php
$host     = getenv('DB_HOST')     ?: 'db';
$username = getenv('DB_USER')     ?: 'root';
$password = getenv('DB_PASSWORD') ?: 'root';
$dbname   = getenv('DB_NAME')     ?: 'gestion_produits';
$port     = getenv('DB_PORT')     ?: '5432';

$db = new PDO("pgsql:host=$host;dbname=$dbname;port=$port", $username, $password);
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
?>
