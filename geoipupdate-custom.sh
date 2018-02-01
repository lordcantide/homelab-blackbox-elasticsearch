# Putting this here in case I forget.
#This shell script downloads the FREE GeoIP data from Maxmind in the MMDB format.
#I couldn't figure out why geoipupdate v2.5 only downloaded DAT files
WORKINGDIRECTORY=$PWD
echo "Downloading GeoLite2-City GeoLite2-Country and GeoLite2-ASN"
curl -o $WORKINGDIRECTORY/untar/GeoLite2-City.tar.gz http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz
curl -o $WORKINGDIRECTORY/untar/GeoLite2-Country.tar.gz http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz
curl -o $WORKINGDIRECTORY/untar/GeoLite2-ASN.tar.gz http://geolite.maxmind.com/download/geoip/database/GeoLite2-ASN.tar.gz
echo "Extracting MMDB files to /usr/local/share/GeoIP/"
tar xvzf $WORKINGDIRECTORY/untar/GeoLite2-City.tar.gz -C $WORKINGDIRECTORY/untar/
tar xvzf  $WORKINGDIRECTORY/untar/GeoLite2-Country.tar.gz -C $WORKINGDIRECTORY/untar/
tar xvzf  $WORKINGDIRECTORY/untar/GeoLite2-ASN.tar.gz -C $WORKINGDIRECTORY/untar/
find $WORKINGDIRECTORY/untar/ -name "*.mmdb" -exec cp {} $WORKINGDIRECTORY \;
rm -rf $WORKINGDIRECTORY/untar/*
echo "Update Complete!"
