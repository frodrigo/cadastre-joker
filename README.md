# cadastre-joker

This project is based on WhooTS to server French Cadastre WMS as TMS.

It just redirect HTTP request after redesign the URL query part.

# Install

```
docker-compose pull
docker-compose build
```

## Run

```
docker-compose up -d
```

## Local Data

Le WMS du cadastre n'est disponible que pour une commune à la fois. Cadastre-joker trouve la bonne commune à utiliser en fonction de la portion de la tuile consultée.

Les polygones de communes proviennent de : https://www.data.gouv.fr/fr/datasets/decoupage-administratif-communal-francais-issu-d-openstreetmap/
- limites de communes
- limites des Arrondissements Municipaux

```
wget https://www.data.gouv.fr/fr/datasets/r/a01aff2a-8f36-4a77-a73f-efc212fe2899 -O communes-20200101-shp.zip
unzip communes-20200101-shp.zip

wget https://www.data.gouv.fr/fr/datasets/r/1b3cc5bf-cad2-42fe-860b-46d8f27e7d39 -O arrondissements_municipaux-20180711-shp.zip
unzip arrondissements_municipaux-20180711-shp.zip

docker-compose exec postgis bash -c "apt update && apt install postgis"
docker-compose exec postgis bash -c "shp2pgsql /data/communes-20200101.shp | psql -U postgres"
docker-compose exec postgis bash -c "shp2pgsql /data/arrondissements_municipaux-20180711.shp | psql -U postgres"

docker-compose exec postgis psql -U postgres -c "
create table communes as select insee, nom, st_setsrid(geom, 4326) as geom from \"communes-20200101\" where insee not in ('13055', '69123', '75056');
insert into communes(insee, nom, geom) SELECT insee, nom, st_setsrid(geom, 4326) as geom from \"arrondissements_municipaux-20180711\";
create index communes_idx on communes using gist(geom);
"
```

# Usage

tms\[20\]:http://localhost:4567/{insee}/{style}/{z}/{x}/{y}.png

* **insee**: à remplacer par le code insee de la commune ou par "*" pour le mode joker automatique (et double joker "**" pour les tuiles complémentaires à cheval sur plusieurs communes)
* **style**: "tout", "semi", "transp" ou un style personnalisé du cadastre
