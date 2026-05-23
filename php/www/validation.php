<?php

    include 'connect.php';

    $action = (isset($_POST['action'])) ? $_POST['action'] : $_GET['action'];

    switch ($action) {
        
        
        case 'ajout_produit':

            $sql = "INSERT INTO produits (PRO_lib, PRO_description, PRO_prix) VALUES (?,?,?)";
            $res = $db->prepare($sql);
            $res->bindParam(1, $_POST['PRO_lib']);
            $res->bindParam(2, $_POST['PRO_description']);
            $res->bindParam(3, $_POST['PRO_prix']);
            $res->execute();
            if ($res) {

                $PRO_id = $db->lastInsertId();

                foreach ($_FILES["PRO_ressources"]["error"] as $key => $error) {
                    if ($error == UPLOAD_ERR_OK) {
                        $tmp_name = $_FILES["PRO_ressources"]["tmp_name"][$key];
                        $extension = pathinfo($_FILES["PRO_ressources"]["name"][$key],PATHINFO_EXTENSION);
                        $md5 = md5_file($tmp_name);
                        $name = $PRO_id."-".$md5.".".$extension;
                        $url = "uploads/$name";
                        move_uploaded_file($tmp_name, $url);

                        $sql = "INSERT INTO ressources (RE_type,RE_url,PRO_id) VALUES ('img',?,?)";
                        $stmt = $db->prepare($sql);
                        $stmt->bindParam(1, $url);
                        $stmt->bindParam(2, $PRO_id);
                        $stmt->execute();
                    }
                }

                header('Location: home.php');

            } else {
                die("Erreur SQL");
            }
            break;


        case 'modification_produit':

            $sql = "UPDATE produits SET PRO_lib = ?, PRO_description = ?, PRO_prix = ? WHERE PRO_id = ?";
            $res = $db->prepare($sql);
            $res->bindParam(1, $_POST['PRO_lib']);
            $res->bindParam(2, $_POST['PRO_description']);
            $res->bindParam(3, $_POST['PRO_prix']);
            $res->bindParam(4, $_POST['PRO_id']);
            $res->execute();
            if ($res) {

                foreach ($_FILES["PRO_ressources"]["error"] as $key => $error) {
                    if ($error == UPLOAD_ERR_OK) {
                        $tmp_name = $_FILES["PRO_ressources"]["tmp_name"][$key];
                        $extension = pathinfo($_FILES["PRO_ressources"]["name"][$key],PATHINFO_EXTENSION);
                        $md5 = md5_file($tmp_name);
                        $name = $_POST['PRO_id']."-".$md5.".".$extension;
                        $url = "uploads/$name";
                        move_uploaded_file($tmp_name, $url);

                        $sql = "INSERT INTO ressources (RE_type,RE_url,PRO_id) VALUES ('img',?,?)";
                        $res = $db->prepare($sql);
                        $res->bindParam(1, $url);
                        $res->bindParam(2, $_POST['PRO_id']);
                        $res->execute();
                    }
                }

                header('Location: produit.php?id='.$_POST['PRO_id']);

            } else {
                die("Erreur SQL");
            }
            break;
        
        
        case 'supprimer_ressource':
            if(isset($_POST['RE_id'])) {

                $sql = "SELECT * FROM ressources WHERE RE_id = ?";
                $res = $db->prepare($sql);
                $res->bindParam(1, $_POST['RE_id']);
                $res->execute();
                $res = $res->fetchAll(PDO::FETCH_ASSOC);
                if(count($res) > 0) {
                    $ressource = $res[0];
                    
                    $sql = "DELETE FROM ressources WHERE RE_id = ?";
                    $res = $db->prepare($sql);
                    $res->bindParam(1, $_POST['RE_id']);
                    $res->execute();
                    if ($res) {
                        if (file_exists($ressource['RE_url'])) {
                            unlink($ressource['RE_url']);
                        }
                        echo 'OK';
                    } else {
                        echo 'NOK';
                    }
                } else {
                    echo 'NOK';
                }
            }
            break;

        
        case 'supprimer_produit':
            if(isset($_POST['PRO_id'])) {
                
                $sql = "SELECT * FROM produits WHERE PRO_id = ?";
                $res = $db->prepare($sql);
                $res->bindParam(1, $_POST['PRO_id']);
                $res->execute();
                $res = $res->fetchAll(PDO::FETCH_ASSOC);
                if(count($res) > 0) {
                    $produit = $res[0];
                    
                    $sql = "SELECT * FROM ressources WHERE PRO_id = ?";
                    $res2 = $db->prepare($sql);
                    $res2->bindParam(1, $_POST['PRO_id']);
                    $res2->execute();
                    $ressources = $res2->fetchAll(PDO::FETCH_ASSOC);
                    foreach($ressources as $ressource) {
                        $RE_id = $ressource['RE_id'];
                        $sql = "DELETE FROM ressources WHERE RE_id = ?";
                        $res = $db->prepare($sql);
                        $res->bindParam(1, $RE_id);
                        $res->execute();
                        if ($res) {
                            if (file_exists($ressource['RE_url'])) {
                                unlink($ressource['RE_url']);
                            }
                        }
                    }

                    $sql = "DELETE FROM produits WHERE PRO_id = ?";
                    $res = $db->prepare($sql);
                    $res->bindParam(1, $_POST['PRO_id']);
                    $res->execute();
                    if ($res) {
                        echo 'OK';
                    } else {
                        echo 'NOK';
                    }

                } else {
                    echo 'NOK';
                }
            }
            break;
        
        
        
        default:
            # code...
            break;
    }


?>