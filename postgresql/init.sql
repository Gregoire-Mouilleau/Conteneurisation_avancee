-- Schéma PostgreSQL adapté depuis MySQL
-- Colonnes en minuscules (convention PostgreSQL)

CREATE TABLE IF NOT EXISTS produits (
    pro_id          SERIAL PRIMARY KEY,
    pro_lib         VARCHAR(200) NOT NULL,
    pro_prix        DECIMAL(10,2) NOT NULL,
    pro_description TEXT
);

CREATE TABLE IF NOT EXISTS ressources (
    re_id   SERIAL PRIMARY KEY,
    re_type VARCHAR(100) NOT NULL,
    re_url  VARCHAR(1000) NOT NULL,
    re_nom  VARCHAR(100) DEFAULT NULL,
    pro_id  INT NOT NULL,
    CONSTRAINT ressources_produits_fk FOREIGN KEY (pro_id) REFERENCES produits (pro_id)
);

CREATE TABLE IF NOT EXISTS utilisateurs (
    us_id       SERIAL PRIMARY KEY,
    us_login    VARCHAR(100) NOT NULL,
    us_password VARCHAR(100) NOT NULL,
    UNIQUE (us_login)
);

-- Données de démonstration
INSERT INTO produits (pro_lib, pro_prix, pro_description) VALUES
('Pédales Shimano XT M8040 M/L', 74.99, 'Les pédales plates SHIMANO XT PD-M8040 sont destinées à un usage All Mountain/Enduro.'),
('Selle FIZIK ARIONE VERSUS Rails Kium', 59.99, 'Modèle confortable avant tout, la selle FIZIK Arione Versus possède un profil tout à fait plat et très long.'),
('Chaussures VTT MAVIC CROSSMAX SL PRO THERMO Noir', 164.99, 'Les chaussures Cross Max SL Pro Thermo créées par la marque MAVIC plairont aux riders voulant profiter de leur vélo en hiver.'),
('Pack GPS GARMIN EDGE 1030 + Ceinture Cardio', 519.99, 'Le Pack GPS Edge 1030 plus la ceinture cardio de Garmin est fait pour les compétiteurs.'),
('Fourche DVO SAPPHIRE 29', 549.99, 'Dérivée de la Diamond, la fourche DVO Sapphire 29" marque l''entrée de la marque californienne dans le segment Trail.');

-- Utilisateur admin (mot de passe : password — hash SHA-256)
INSERT INTO utilisateurs (us_login, us_password) VALUES
('admin', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8');
