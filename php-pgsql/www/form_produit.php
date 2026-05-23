<?php
    session_start();
    include 'connect.php';
    include 'fonctions.php';
    secu();

    if (isset($_GET['id'])) {
        $action = "modification";
        $pro_id = $_GET['id'];

        $sql = "SELECT * FROM produits WHERE pro_id = ?";
        $res = $db->prepare($sql);
        $res->bindParam(1, $pro_id);
        $res->execute();
        if ($res === false) {
            header('Location: home.php');
        } else {
            $produit = $res->fetch(PDO::FETCH_ASSOC);
        }
    } else {
        $action = "ajout";
        $produit = array(
            'pro_id' => '',
            'pro_lib' => '',
            'pro_description' => '',
            'pro_prix' => 0
        );
    }

?><!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>Gestion des produits</title>
    <script src="https://code.jquery.com/jquery-3.3.1.min.js"></script>
    <script src="fonctions.js"></script>
    <link href="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" crossorigin="anonymous">
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <h2>Fiche produit</h2>
        <form action="validation.php" method="post" enctype="multipart/form-data">

            <input type="hidden" id="action" name="action" value="<?php echo $action ?>_produit" >
            <?php
                if ($action == 'modification') {
            ?>
            <input type="hidden" id="pro_id" name="pro_id" value="<?php echo $pro_id ?>" >
            <?php
                }
            ?>


            <div class="form-group">
                <label for="pro_lib">Libellé</label>
                <input type="text" class="form-control" id="pro_lib" name="pro_lib" value="<?php echo $produit['pro_lib'] ?>" required>
            </div>

            <div class="form-group">
                <label for="pro_description">Description</label>
                <textarea class="form-control" id="pro_description" name="pro_description" rows="10"><?php echo $produit['pro_description'] ?></textarea>
            </div>

            <div class="form-group">
                <label for="pro_prix">Prix (€)</label>
                <input type="number" class="form-control text-right" id="pro_prix" name="pro_prix" value="<?php echo $produit['pro_prix'] ?>" step="0.01" min="0" required>
            </div>

            <div class="form-group">
                <label for="PRO_ressources">Ressources (images)</label>

                <?php
                    if ($action == 'modification') {
                        $sql = "SELECT * FROM ressources WHERE pro_id = ?";
                        $res = $db->prepare($sql);
                        $res->bindParam(1, $pro_id);
                        $res->execute();
                        if ($res != false) {
                            echo "<div>";
                            while ($ressource = $res->fetch(PDO::FETCH_ASSOC)) {
                                if ($ressource['re_type'] == 'img') {
                                    echo '<div class="img">';
                                    echo '<img src="'.$ressource['re_url'].'" class="img-thumbnail thumb" data-id="'.$ressource['re_id'].'">';
                                    echo '<img src="img/trash.svg" class="icon trash" data-id="'.$ressource['re_id'].'">';
                                    echo '</div>';
                                }
                            }
                            echo "</div>";
                        }
                    }
                ?>

                <input type="file" id="PRO_ressources" name="PRO_ressources[]" multiple class="form-control" accept="image/png, image/jpeg">
            </div>

            <div class="form-group" style="margin-top: 20px;">
                    <button type="submit" class="btn btn-warning">Enregistrer</button>
                     <?php
                        if ($action == 'modification') {
                    ?>
                    <button type="button" class="btn btn-danger delete">Supprimer le produit</button>
                    <?php
                        }
                    ?>
                    <button type="button" class="btn btn-primary" onClick="goto('home.php')">Retour</button>
            </div>
        </form>

    </div>


    <script>
        $('img.icon.trash').click(function() {
            if(confirm("Etes-vous sûr de vouloir supprimer cette photo?")) {
                var re_id = $(this).attr('data-id');
                
                request = $.ajax({
                    method: "POST",
                    url: "validation.php",
                    data: { action: 'supprimer_ressource', re_id: re_id }
                }).done(function( msg ) {
                    if (msg == 'OK') {
                        document.location.reload();
                    } else if (msg == 'NOK') {
                        document.location.reload();
                    } else {
                        alert(msg);
                    }
                });
            }
        });

        $('button.delete').click(function() {
            
            if(confirm("Etes-vous sûr de vouloir supprimer ce produit?")) {
                var pro_id = $('#pro_id').val();

                request = $.ajax({
                    method: "POST",
                    url: "validation.php",
                    data: { action: 'supprimer_produit', pro_id: pro_id }
                }).done(function( msg ) {
                    if (msg == 'OK') {
                        goto('home.php');
                    } else if (msg == 'NOK') {
                        document.location.reload();
                    } else {
                        alert(msg);
                    }
                });
            }
        });
    </script>
</body>
</html>