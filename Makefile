# Hopefully when initting, node will install topojson.

TOPOJSON := ./node_modules/bin/topojson

all: init \
	 sample

sample: \
	 data/neighborhoods.kml \
	 json/neighborhoods.topo.json \
	 json/neighborhoods_and_shadings.topo.json

data/neighborhoods.kml: data_src/mpls_neighborhoods/neighbor2002.shp
	ogr2ogr -F KML -s_srs EPSG:3745 -t_srs EPSG:4326 $@ $^

clean:
	rm -rf json/*.topo.json \
	   data/*.geo.json \
	   data/*.kml \
	   data/*.json \
	   data_src/mpls_neighborhoods \
	   tmp \
	   data \
	   json \
	   node_modules 

# Neighborhoods
# source datum: NAD83 - utm zone 15 - EPSG:3745
#
# Note that when you're working with new data sets, it's important to get this
# right...

# If you had another GeoJSON data source to include in the same output file,
# you'd add another line here:
#
#	-- \
#		neighborhoods=data/neighborhoods.geo.json \
#		water=data/water.topo.json \

json/neighborhoods_and_shadings.topo.json: data/neighborhoods.geo.json \
										   data_src/neighborhood_counts.tsv
	topojson $^ \
		--id-property OBJECTID \
		--bbox -p \
		-e data_src/neighborhood_counts.tsv --id-property NAMEUPPER \
		-- \
			neighborhoods=data/neighborhoods.geo.json \
		> $@

json/neighborhoods.topo.json: data/neighborhoods.geo.json
	topojson $^ \
		--id-property OBJECTID \
		--bbox -p \
		-- \
			neighborhoods=data/neighborhoods.geo.json \
		> $@

data/neighborhoods.geo.json: data_src/mpls_neighborhoods/neighbor2002.shp
	ogr2ogr \
		-F GeoJSON \
		-s_srs EPSG:3745 \
		-t_srs EPSG:4326 \
		$@ \
		$^

data/neighborhoods_reprojected.shp: data_src/mpls_neighborhoods/neighbor2002.shp
	ogr2ogr \
		-F "ESRI Shapefile" \
		-s_srs EPSG:3745 \
		-t_srs EPSG:4326 \
		$^ \
		$@

data_src/mpls_neighborhoods/neighbor2002.shp:
	wget http://www.crcworks.org/hennepin/data/MplsNhoods2002.zip && \
	mkdir -p data_src/mpls_neighborhoods/ && \
	unzip MplsNhoods2002.zip -d data_src/mpls_neighborhoods/


INITTED := $(wildcard tmp)

ifneq ($(strip $(INITTED)),)
init:
	@echo "Already initted..."
else
init:
	mkdir json
	mkdir data
	npm install
endif

