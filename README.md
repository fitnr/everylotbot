# every lot bot

This bot tweets Google Streetview pictures of every property in a city. Really, it tweets Streetview photos of every property in a SQLite database.

## What you'll need

Set up will be easier with at least a basic familiarity with the command line. A knowledge of GIS may be helpful.

* A fresh Twitter account and a Twitter app, with registered keys
* A Google Streetview API token.
* A SQLite db with a row for every address you're interested in
* A place to run the bot (like a dedicated server or an Amazon AWS EC2 instance)

### Twitter keys

Creating Twitter account should be straightforward. To create a Twitter app, register at [apps.twitter.com/](http://apps.twitter.com/). Once you have an app, you'll need to register your account with the app. [Twitter has details](https://dev.twitter.com/oauth/overview/application-owner-access-tokens).

Once you have the keys, save them in a file called `bots.yaml` in this format:

```yaml
apps:
    example_app_name:
        consumer_key: 123456890123456890
        consumer_secret: 123456890123456890123456890123456890
users:
    example_user_name:
        key: 123456890123456890-123456890123456890123456890123456890
        secret: 1234568901234568901234568901234568901234568
        app: example_app_name
```

Change `example_user_name` to your Twitter account screen name, and each `example_user_name` to a nickname for your app.

### Streetview key

Visit the [Google Street View Image API](https://developers.google.com/maps/documentation/streetview/) page and click get a key.

Once you have the key, save it on its own line in your `bots.yaml` file like so:
```yaml
streetview: 123ABC123ABC123ABC123ABC
```

### Address database

Now, you'll need an SQLite database of addresses. At a minimum, the address database just needs an id field and list of addresses. It's helpful to also have a lat/lon coordinates, since if the Google API can't find a nearby address, the bot will use lat/lon instead.

One way to get this database is to download geodata and convert to to SQLite. Visit your county's open data page (if it has one). Ideally, you'll end up with the data in Shapefile format, which is actually four or five files that look like:
```
Parcels_2015.dbf Parcels_2015.prj Parcels_2015.shp Parcels_2015.shx Parcels_2015.shp.xml
```

While you're at it, make sure to download the metadata and carefully note the fields you'll want to track. At a minimum, you'll need an ID field and an address field. The address may be broken into several parts, that's fine. A field that tracts the number of floors would be nice, too.

Now, you'll need to transform that Shapefile into an SQLite database. If you are a GIS expert, you may find it easy to open up your favorite GIS and go nuts. 

If you're on OS X and don't have a GIS handy, install [Homebrew](http://brew.sh). Then, paying attention to the fields you noted, do something like this:

````
# this will take a while, you're installing a big software library
brew install gdal

# Convert the layer to Google's projection and filter the fields
ogr2ogr -f SQLite Parcels_2015_4326.db Parcels_2015.db -t_srs EPSG:4326 -select taxid,addr,floors

ogr2ogr -f SQLite lots.db Parcels_2015_4326.db -nln lots \
    -sql "SELECT taxid AS id, addr AS address, floors, \
        ROUND(X(ST_Centroid(GeomFromWKB(Geometry))), 5) lon, \
        ROUND(Y(ST_Centroid(GeomFromWKB(Geometry))), 5) lat, \
        0 tweeted \
        FROM Parcels_2015_4326 ORDER BY taxid ASC"
````

If the above is impentrable, you can convert a CSV to SQLite with one step:
````
sqlite3 lots.db "import 'stdin' lots" < lots.csv
````

### A place for your bot to live

Now, you just need a place for the bot to live. This needs to be a computer that's always connected to the internet, and that you can set up to run tasks for you.

Put the `bots.yaml` file and your database in the same folder on the computer, then download this repository and install it:
```
python setup.py install
mkdir ~/logs
```

(`everylotbot` automatically creates a log in ~/logs)

If this is a Linux machine, you can do this with crontab:
```
crontab -e
1,31 * * * * $HOME/.local/bin/everylotbot twitter_screen_name $HOME/path/to/lots.db -s '{address} Anytown USA'

### Walkthrough for Baltimore

First step is to find the bata: google "Baltimore open data", search for parcels on [data.baltimorecity.gov](https://data.baltimorecity.gov).

````bash
> curl -G https://data.baltimorecity.gov/api/geospatial/rb22-mgti \
    -d method=export -d format=Shapefile -o baltimore.zip
> unzip baltimore.zip
Archive:  baltimore.zip
  inflating: geo_export_9f6b494d-b617-4065-a8e7-23adb09350bc.shp  
  inflating: geo_export_9f6b494d-b617-4065-a8e7-23adb09350bc.shx  
  inflating: geo_export_9f6b494d-b617-4065-a8e7-23adb09350bc.dbf  
  inflating: geo_export_9f6b494d-b617-4065-a8e7-23adb09350bc.prj

# Get a simpler name
> mv geo_export_9f6b494d-b617-4065-a8e7-23adb09350bc.shp baltimore.shp
> mv geo_export_9f6b494d-b617-4065-a8e7-23adb09350bc.shx baltimore.shx
> mv geo_export_9f6b494d-b617-4065-a8e7-23adb09350bc.dbf baltimore.dbf

# Find the address field
> ogrinfo baltimore.shp baltimore -so
INFO: Open of `baltimore.shp'
      using driver `ESRI Shapefile' successful.
...
parcelnum: String (254.0)
...
blocknum: String (254.0)
fulladdr: String (254.0)
...
# Convert to WGS84, only using the desired fields
> ogr2ogr -f SQLite baltimore_raw.db baltimore.shp baltimore -t_srs EPSG:4326 \
    -nln baltimore -select parcelnum,blocknum,fulladdr

# Convert feature centroid to integer latitude, longitude
# Pad the block number and parcel number so make sorting work better
# http://stackoverflow.com/questions/6134415/how-to-concatenate-strings-with-padding-in-sqlite
> ogr2ogr -f SQLite baltimore.db baltimore_raw.db -nln lots -dialect sqlite \
    -sql "SELECT (substr('00000' || blocknum, -5, 5)) || \
    (substr('000000000' || parcelnum, -9, 9)) AS id, \
    fulladdr AS address, \
    ROUND(X(ST_Centroid(GeomFromWKB(Geometry))), 5) lon, \
    ROUND(Y(ST_Centroid(GeomFromWKB(Geometry))), 5) lat, \
    0 tweeted FROM baltimore WHERE blocknum IS NOT NULL AND parcelnum IS NOT NULL;"

# add indexes and clean up sqlite database
> sqlite3 baltimore.db "CREATE INDEX i ON lots (id);"
> sqlite3 baltimore.db "DELETE FROM lots WHERE id = '' OR id IS NULL;"
> sqlite3 baltimore.db "DROP TABLE geometry_columns; DROP TABLE spatial_ref_sys; VACUUM;"
> everylot everylotbaltimore baltimore.db --search_format "{address}, Baltimore, MD" --print_format "{address}"
````
