require 'rubygems'
require 'rack'
require 'sinatra'
require 'erb'
require 'pg'
require 'connection_pool'
enable :inline_template


con_pool = ConnectionPool.new(size: 5, timeout: 10) {
  PG.connect(host: 'postgis', dbname: 'postgres', user: 'postgres', password: 'postgres')
}


get '/hi' do
  "Hello World!"
end

get '/' do
  erb :index
end

get '/:insee/:style/:z/:x/:y.png' do
  insee = params[:insee]
  style = params[:style]
  x = params[:x].to_i
  y = params[:y].to_i
  z = params[:z].to_i
  #for Google/OSM tile scheme we need to alter the y:
  y = ((2**z)-y-1)
  #calculate the bbox
  min = get_lat_lng_for_number(x, y, z)
  max = get_lat_lng_for_number(x+1, y+1, z)
  bbox = "#{min[:lat_deg]},#{min[:lng_deg]},#{max[:lat_deg]},#{max[:lng_deg]}"
  #build up the other params
  request = "GetMap"
  srs = "EPSG:4326"
  width = "256"
  height = "256"
  transp = false
  if insee[0] == "*"
    offset = insee.size - 1
    if offset >= 1
      transp = true
    end
    con_pool.with{ |conn|
      conn.exec( """
SELECT insee
FROM \"communes\"
WHERE geom && ST_SetSRID(ST_MakeLine(ST_MakePoint(#{min[:lng_deg]}, #{min[:lat_deg]}), ST_MakePoint(#{max[:lng_deg]}, #{max[:lat_deg]})),4326)
ORDER BY ST_Area(ST_Intersection(geom, ST_SetSRID(ST_Envelope(ST_MakeLine(ST_MakePoint(#{min[:lng_deg]}, #{min[:lat_deg]}), ST_MakePoint(#{max[:lng_deg]}, #{max[:lat_deg]}))),4326))) DESC, insee
LIMIT 1 OFFSET #{offset}""" ) do |result|
        result.each do |row|
          insee = row.values_at('insee')[0]
        end
      end
    }
    if insee[0] == "*"
      redirect "/empty.png"
    end
  end
  if style == 'tout' || style == nil
    style = "BU.Building,AMORCES_CAD,CP.CadastralParcel,HYDRO,BORNE_REPERE,DETAIL_TOPO,LIEUDIT,VOiE_COMMUNICATION"
  elsif style == 'semi'
    style = "AMORCES_CAD,CP.CadastralParcel,BORNE_REPERE,DETAIL_TOPO,LIEUDIT,VOiE_COMMUNICATION"
  elsif style == 'transp'
    style = "AMORCES_CAD,CP.CadastralParcel,BORNE_REPERE,DETAIL_TOPO,LIEUDIT,VOiE_COMMUNICATION&TRANSPARENT=TRUE"
  end
  if transp
    style += "&TRANSPARENT=TRUE"
  end
  url = "https://www.cadastre.gouv.fr/scpc/#{insee}.wms?service=WMS&request=GetMap&VERSION=1.3&CRS=#{srs}&WIDTH=#{width}&HEIGHT=#{height}&BBOX=#{bbox}&LAYERS=#{style}&STYLES=&FORMAT=image/png"
  redirect url
end

def get_lat_lng_for_number(xtile, ytile, zoom)
  n = 2.0 ** zoom
  lon_deg = xtile / n * 360.0 - 180.0
  lat_rad = Math::atan(Math::sinh(Math::PI * (1 - 2 * ytile / n)))
  lat_deg = 180.0 * (lat_rad / Math::PI)
  {:lat_deg => -lat_deg, :lng_deg => lon_deg}
end


__END__

@@ layout
<%= yield %>

@@ index
<!DOCTYPE html>
<html>
<head>
    <title>Redirection HTTP de tuile TMS vers le WMS du Cadastre</title>
    <meta charset="utf-8" />

    <script src="leaflet.js"></script>
    <link rel="stylesheet" href="leaflet.css" />
</head>
<body>
    <div id="map" style="width: 100%; height: 600px"></div>

    <script>
        var map = L.map('map').setView([44.8265, -0.5692], 13);

        L.tileLayer('/*/tout/{z}/{x}/{y}.png', {
            maxZoom: 20,
            attribution: 'Cadastre',
        }).addTo(map);
        L.tileLayer('/**/tout/{z}/{x}/{y}.png', {
            maxZoom: 20,
            attribution: 'Cadastre',
        }).addTo(map);
    </script>
<% host = request.host + (request.port != 80 ? ":#{request.port.to_s}" : "") %>
tms[20]:http://<%= host %>/{insee}/{style}/{z}/{x}/{y}.png
<ul>
  <li>{insee}: à remplacer par le code insee de la commune ou par "*" pour le mode joker automatique (et double joker "**" pour les tuiles complémentaires à cheval sur plusieurs communes)</li>
  <li>{style}: "tout", "semi", "transp" ou un style personalisé du cadastre</li>
</lu>
</body>
</html>
