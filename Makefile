VERSION = 15v1

PLUTO_FIELDS = BBL,Address,BoroCode,ZipCode,NumFloors

CREATE_PLUTO = CREATE TABLE lots ( \
	"id" INTEGER, \
	"address" VARCHAR(27), \
	"borocode" VARCHAR(1) NOT NULL, \
	"zip" INTEGER NOT NULL, \
	"floors" DOUBLE, \
	"lon" DOUBLE, \
	"lat" DOUBLE, \
	"tweeted" VARCHAR(16) \
); CREATE INDEX i ON lots (id);

BOROUGHS = mn bx bk qn si

mn = Manhattan/MN
bx = Bronx/BX
bk = Brooklyn/BK
qn = Queens/QN
si = Staten_Island/SI

.PHONY: develop install requirements

install develop: %:
	python setup.py $(SETUPFLAGS) $* $(PYTHONFLAGS)

# New York City
pluto.db: $(addsuffix .db,$(BOROUGHS))
	sqlite3 $@ "$(CREATE_PLUTO);"
	for db in $^; do \
	    ogr2ogr $@ $$db -update -append -nln lots -dialect sqlite \
	    -sql "SELECT CAST(BBL as INTEGER) id, \
	    Address, BoroCode, ZipCode, NumFloors, \
	    ROUND(X(ST_Centroid(GeomFromWKB(Geometry))), 5) lon, \
	    ROUND(Y(ST_Centroid(GeomFromWKB(Geometry))), 5) lat, 0 \
	    FROM pluto ORDER BY CAST(BBL as INTEGER) ASC" \
	done

	sqlite3 $@ "DELETE FROM lots WHERE id = '' OR id IS NULL"
	sqlite3 $@ "UPDATE lots SET address = 'South Street at FDR Drive' WHERE id=1000030004 AND address IS NULL"
	sqlite3 $@ "UPDATE lots SET address = '13 Stone Street' WHERE id=1000110028 AND address IS NULL"

$(addsuffix .db,$(BOROUGHS)): %.db: %_mappluto_15v1.zip
	ogr2ogr -f SQLite $@ /vsizip/$</$($*)MapPLUTO.shp \
	-nln pluto -t_srs EPSG:4326 -select $(PLUTO_FIELDS)

$(addsuffix _mappluto_$(VERSION).zip,$(BOROUGHS)): %_mappluto_$(VERSION).zip:
	curl -O http://www.nyc.gov/html/dcp/download/bytes/$@

# Los Angeles

los_angeles.db: los_angeles_raw.db
	ogr2ogr -f SQLite $@ $< -nln lots -dialect sqlite -sql "SELECT CAST(AIN as INTEGER) id, \
	    SUBSTR(situsaddr, 0, INSTR(situsaddr, '  ')) address, \
	    SUBSTR(situsaddr, INSTR(situsaddr, ' 9') + 1, LENGTH(situsaddr)) zip, \
	    ROUND(X(ST_Centroid(GeomFromWKB(Geometry))), 5) lon, \
	    ROUND(Y(ST_Centroid(GeomFromWKB(Geometry))), 5) lat, \
	    0 tweeted \
	    FROM los_angeles WHERE situsaddr LIKE '% LOS ANGELES CA %' \
	    ORDER BY CAST(AIN as INTEGER) ASC;"

	sqlite3 $@ "CREATE INDEX i ON lots (id);"
	sqlite3 $@ "DELETE FROM lots WHERE id = '' OR id IS NULL;"
	sqlite3 $@ "DROP TABLE geometry_columns; DROP TABLE spatial_ref_sys; VACUUM;"

los_angeles_raw.db: PARCELS2015.shp
	ogr2ogr -f SQLite $@ $< $(basename $<) \
	-t_srs EPSG:4326 -nln los_angeles -select $(LA_FIELDS)
	@touch $@

# features: 2391896
# 785156 LIKE '% LOS ANGELES %'
./PARCELS2015.shp: la.zip
	unzip -j -d $(@D) $<
	@touch $@

la.zip: 
	curl -GL -d method=export -d format=Original \
	    https://data.lacounty.gov/api/geospatial/52g2-xk3i > $@

