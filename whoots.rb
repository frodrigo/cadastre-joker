require 'rubygems'
require 'rack'
require 'sinatra'
require 'erb'
require 'pg'
enable :inline_template


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
    conn = PG.connect(dbname: 'fred')
    conn.exec( """
SELECT insee
FROM \"communes-20150101-5m\"
WHERE the_geom && ST_MakeLine(ST_MakePoint(#{min[:lng_deg]}, #{min[:lat_deg]}), ST_MakePoint(#{max[:lng_deg]}, #{max[:lat_deg]}))
ORDER BY ST_Area(ST_Intersection(the_geom, ST_Envelope(ST_MakeLine(ST_MakePoint(#{min[:lng_deg]}, #{min[:lat_deg]}), ST_MakePoint(#{max[:lng_deg]}, #{max[:lat_deg]}))))) DESC, insee
LIMIT 1 OFFSET #{offset}""" ) do |result|
      result.each do |row|
        insee = row.values_at('insee')[0]
      end
    end
    if insee[0] == "*"
      status 200
      body ''
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
  url = "http://inspire.cadastre.gouv.fr/scpc/#{insee}.wms?service=WMS&request=GetMap&VERSION=1.3&CRS=#{srs}&WIDTH=#{width}&HEIGHT=#{height}&BBOX=#{bbox}&LAYERS=#{style}&STYLES=&FORMAT=image/png"
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
<html><head><title>WhooTS - the tiny public wms to tms proxy</title>
<style>body{font-family: Arial, Helvetica, sans-serif;}</style>
</head><body>
<h1><img src="whoots_tiles.jpg" />
WhooTS - the tiny public wms to tms proxy</h1>
<%= yield %>
<hr />
<p>About: Made with Sinatra and Ruby by Tim Waters tim@geothings.net  <a href="http://thinkwhere.wordpress.com/">Blog</a><br />
Code available at: <a href="http://github.com/timwaters/whoots">github</a></p>
</body></html>

@@ index
<h2>What is it?</h2>
<p>It's a simple WMS to Google/OSM Scheme TMS proxy. You can use WMS servers in applications which only use those pesky "Slippy Tiles"
</p>


<h2>Usage:</h2>
<h4>http://<%=request.host%>:<%=request.port%>/tms/z/x/y/{layer}/http://path.to.wms.server</h4>

e.g<br />
http://<%=request.host%>:<%=request.port%>/tms/!/!/!/2013/http://warper.geothings.net/maps/wms/2013<br />
http://<%=request.host%>:<%=request.port%>/tms/z/x/y/870/http://maps.nypl.org/warper/layers/wms/870<br />
<br />
Using this WMS server:<br />
http://hypercube.telascience.org/cgi-bin/mapserv?map=/home/ortelius/haiti/haiti.map&request=getMap&service=wms&version=1.1.1&format=image/jpeg&srs=epsg:4326&exceptions=application/vnd.ogc.se_inimage&layers=HAITI&<br /><br />
http://<%=request.host%>:<%=request.port%>/tms/!/!/!/HAITI/http://hypercube.telascience.org/cgi-bin/mapserv?map=/home/ortelius/haiti/haiti.map<br />
<br />
http://<%=request.host%>:<%=request.port%>/tms/19/154563/197076/870/http://maps.nypl.org/warper/layers/wms/870

<h2>Openstreetmap Potlatch editing example </h2>

<h3>Map Warper <a href="http://warper.geothings.net">http://warper.geothings.net</a> </h3>
WMS Link: http://warper.geothings.net/maps/wms/2013<br />
<br />
http://www.openstreetmap.org/edit?lat=18.601316&lon=-72.32806&zoom=18&tileurl=http://<%=request.host%>:<%=request.port%>/tms/!/!/!/2013/http://warper.geothings.net/maps/wms/2013

<h3>NYPL Map Rectifier <a href="http://maps.nypl.org">http://maps.nypl.org</a></h3>

http://www.openstreetmap.org/edit?lat=40.73658&lon=-73.87108&zoom=17&tileurl=http://<%=request.host%>:<%=request.port%>/tms/!/!/!/870/http://maps.nypl.org/warper/layers/wms/870



<h3>Telascience Haiti <a href="http://hypercube.telascience.org/haiti/">http://hypercube.telascience.org/haiti/</a></h3>
http://www.openstreetmap.org/edit?lat=18.601316&lon=-72.32806&zoom=18&tileurl=http://<%=request.host%>:<%=request.port%>/tms/!/!/!/HAITI/http://hypercube.telascience.org/cgi-bin/mapserv?map=/home/ortelius/haiti/haiti.map<br /><br />

<h2>Example Outputs</h2>
http://hypercube.telascience.org/cgi-bin/mapserv?bbox=-8051417.93739076,2107827.49199202,-8051265.06333419,2107980.36604859&format=image/png&service=WMS&version=1.1.1&request=GetMap&srs=EPSG:900913&width=256&height=256&layers=HAITI&map=/home/ortelius/haiti/haiti.map&styles=
<br /><br />
http://maps.nypl.org/warper/layers/wms/870?bbox=-8223095.50291926,4973298.80834671,-8222789.75480612,4973604.55645985&format=image/png&service=WMS&version=1.1.1&request=GetMap&srs=EPSG:900913&width=256&height=256&layers=870&map=&styles=
<br />

<h2>Important Notes</h2>
* Use only a WMS that supports SRS EPSG:900913 <br />
* Tiles are Google / OSM Scheme

