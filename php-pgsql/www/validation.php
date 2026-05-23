<?php

    include 'connect.php';

    $action = (isset($_POST['action'])) ? $_POST['action'] : $_GET['action'];

    switch ($action) {
        
        
        case 'ajout_produit':

            $sql = "INSERT INTO produits (pro_lib, pro_description, pro_prix) VALUES (?,?,?)";
            $res = $db->prepare($sql);
            $res->bindParam(1, $_POST['pro_lib']);
            $res->bindParam(2, $_POST['pro_description']);
            $res->bindParam(3, $_POST['pro_prix']);
            $res->execute();
            if ($res) {

                $pro_id = $db->lastInsertId();

                foreach ($_FILES["PRO_ressources"]["error"] as $key => $error) {
                    if ($error == UPLOAD_ERR_OK) {
                        $tmp_name = $_FILES["PRO_ressources"]["tmp_name"][$key];
                        $extension = pathinfo($_FILES["PRO_ressources"]["name"][$key],PATHINFO_EXTENSION);
                        $md5 = md5_file($tmp_name);
                        $name = $pro_id."-".$md5.".".$extension;
                        $url = "uploads/$name";
                        move_uploaded_file($tmp_name, $url);

                        $sql = "INSERT INTO ressources (re_type,re_url,pro_id) VALUES ('img',?,?)";
                        $stmt = $db->prepare($sql);
                        $stmt->bindParam(1, $url);
                        $stmt->bindParam(2, $pro_id);
                        $stmt->execute();
                    }
                }

                header('Location: home.php');

            } else {
                die("Erreur SQL");
            }
            break;


        case 'modification_produit':

            $sql = "UPDATE produits SET pro_lib = ?, pro_description = ?, pro_prix = ? WHERE pro_id = ?";
            $res = $db->prepare($sql);
            $res->bindParam(1, $_POST['pro_lib']);
            $res->bindParam(2, $_POST['pro_description']);
            $res->bindParam(3, $_POST['pro_prix']);
            $res->bindParam(4, $_POST['pro_id']);
            $res->execute();
            if ($res) {

                foreach ($_FILES["PRO_ressources"]["error"] as $key => $error) {
                    if ($error == UPLOAD_ERR_OK) {
                        $tmp_name = $_FILES["PRO_ressources"]["tmp_name"][$key];
                        $extension = pathinfo($_FILES["PRO_ressources"]["name"][$key],PATHINFO_EXTENSION);
                        $md5 = md5_file($tmp_name);
                        $name = $_POST['pro_id']."-".$md5.".".$extension;
                        $url = "uploads/$name";
                        move_uploaded_file($tmp_name, $url);

                        $sql = "INSERT INTO ressources (re_type,re_url,pro_id) VALUES ('img',?,?)";
                        $res = $db->prepare($sql);
                        $res->bindParam(1, $url);
                        $res->bindParam(2, $_POST['pro_id']);
                        $res->execute();
                    }
                }

                header('Location: produit.php?id='.$_POST['pro_id']);

            } else {
                die("Erreur SQL");
            }
            break;
        
        
        case 'supprimer_ressource':
            if(isset($_POST['re_id'])) {

                $sql = "SELECT * FROM ressources WHERE re_id = ?";
                $res = $db->prepare($sql);
                $res->bindParam(1, $_POST['re_id']);
                $res->execute();
                $res = $res->fetchAll(PDO::FETCH_ASSOC);
                if(count($res) > 0) {
                    $ressource = $res[0];
                    
                    $sql = "DELETE FROM ressources WHERE re_id = ?";
                    $res = $db->prepare($sql);
                    $res->bindParam(1, $_POST['re_id']);
                    $res->execute();
                    if ($res) {
                        if (file_exists($ressource['re_url'])) {
                            unlink($ressource['re_url']);
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
            if(isset($_POST['pro_id'])) {
                
                $sql = "SELECT * FROM produits WHERE pro_id = ?";
                $res = $db->prepare($sql);
                $res->bindParam(1, $_POST['pro_id']);
                $res->execute();
                $res = $res->fetchAll(PDO::FETCH_ASSOC);
                if(count($res) > 0) {
                    $produit = $res[0];
                    
                    $sql = "SELECT * FROM ressources WHERE pro_id = ?";
                    $res2 = $db->prepare($sql);
                    $res2->bindParam(1, $_POST['pro_id']);
                    $res2->execute();
                    $ressources = $res2->fetchAll(PDO::FETCH_ASSOC);
                    foreach($ressources as $ressource) {
                        $re_id = $ressource['re_id'];
                        $sql = "DELETE FROM ressources WHERE re_id = ?";
                        $res = $db->prepare($sql);
                        $res->bindParam(1, $re_id);
                        $res->execute();
                        if ($res) {
                            if (file_exists($ressource['re_url'])) {
                                unlink($ressource['re_url']);
                            }
                        }
                    }

                    $sql = "DELETE FROM produits WHERE pro_id = ?";
                    $res = $db->prepare($sql);
                    $res->bindParam(1, $_POST['pro_id']);
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