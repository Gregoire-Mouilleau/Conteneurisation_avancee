<?php
    if (isset($_POST['US_login']) and isset($_POST['US_password'])) {
        session_start();
        include 'connect.php';

        ini_set('display_errors', '1');

        $sql = "SELECT * FROM utilisateurs WHERE US_login = ? AND US_password = SHA2(?, 256)";
        $stmt = $db->prepare($sql);
        $stmt->bindParam(1, $_POST['US_login']);
        $stmt->bindParam(2, $_POST['US_password']);
        $stmt->execute();
        $res = $stmt->fetchAll(PDO::FETCH_ASSOC);
        if ($res != false) {

            if ( count($res) > 0) {
                // Utilisateur trouvé dans la base
                $utilisateur = $res[0];
                $_SESSION['login'] = $utilisateur['US_login'];
                header("Location: home.php");
            } else {
                header("Location: index.php");
            }
        } else {
            header("Location: BADUSER.html");
        }
    }
?>