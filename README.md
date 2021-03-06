# homelab-blackbox-elasticsearch
Practicing system analytics using Elastic Search.

## Introduction
This documentation covers my attempt to install the Elastic Search Stack in my personal homelab. Elastic Search will be used to analyze data pulled from devices attached to my network including:
* a pfSense router
* a ubiquiti EdgeSwitch
* a unifi wifi access point
* a FreeNAS host and jails
* a Hunnewell wifi thermostat
* a desktop

### Environmental Notes
ElasticSearch documentation heavily supports running under a linux distribution; however, my only available hardware to run from at this time currently runs FreeNAS. I prefer FreeNAS jails for efficiency while I wait to set up my new Proxmox host in several months. Until I set up an LXC on Proxmox, I am left to assume that the challenges I've had are unique to FreeBSD jail variants.

### Platform
Freenas 11.1 jail with ElasticSearch (5.6), Logstash (5.6), and Kibana (5.6) installed on the same instance. Additionally, an nginx reverse proxy is recommended for user access. Elastic Beats will be installed as an agent on client machines to ship the telemetry to Logstash. Since these applications are installed on a single platform, the default configuration may lead to a network port conflict. The ports documented below may not be the default ports found in your installation.

## Referenced links
There were several gaps because of versions, platforms, and time that cropped up with the sources below, but they were an excellent start.

https://www.elastic.co/guide/en/logstash/5.6/configuration.html

https://extelligenceblog.it/2017/07/11/elastic-stack-suricata-idps-and-pfsense-firewall-part-1/

https://blog.gufi.org/2016/02/15/elk-first-part/

https://project.altservice.com/issues/414

http://pfelk.3ilson.com/

## Setting up the Platform
1. Create Jail.
2. Set up portsnap, pkg, and portmaster. Make sure packages and ports in jail are up to date.
```shell
portsnap fetch extract && pkg upgrade -y
cd /usr/ports/ports-mgmt/portmaster/ && make install clean
portmaster -a
```
3. Install ElasticSearch, Logstash, Kibana, and nginx. Personally, I'm using ports instead of packages so I can get the latest version without having to wait for someone else to compile; however, the java/openjdk8 runtime dependency can take hours to compile so I'm going to install that as a package ahead of the ports. Ensure that the build is the latest version as a new base build such as Logstash6 may become available soon.
```shell
pkg install openjdk8
cd /usr/ports/textproc/elasticsearch5/ && make install clean
cd /usr/ports/sysutils/logstash5/ && make install clean
cd /usr/ports/textproc/kibana5/ && make install clean
cd /usr/ports/www/nginx/ && make install clean
cd /usr/ports/security/p5-Apache-Htpasswd/ && make install clean
```
**NOTE:** p5-Apache-Htpasswd is only needed if you are implementing basic authentication to the nginx proxy.

4. Enable the ElasticSearch, Logstash, Kibana, and nginx services. Specify directory for logstash service log (I'm keeping mine in the logstash application directory).
```shell
echo 'elasticsearch_enable="YES"' > /etc/rc.conf.d/elasticsearch
printf 'logstash_enable="YES"\nlogstash_log="YES"\nlogstash_log_file="/var/log/logstash/logstash.log"' > /etc/rc.conf.d/logstash
echo 'kibana_enable="YES"' > /etc/rc.conf.d/kibana
echo 'nginx_enable="YES"' > /etc/rc.conf.d/nginx
```
## Configure ElasticSearch
1. Edit elasticsearch.yml: `ee /usr/local/etc/elasticsearch/elasticsearch.yml`
2. Under the Network section, change the default value for `#network.host...` to `network.host: 127.0.0.1`
3. A few lines down from there, change `#http.port...` to `http.port: 9100` (assuming no conflicts and 9100 is not your install's default port). Save and exit the file.
4. Start ElasticSearch: `service elasticsearch start`

## Configure Logstash (syslog only)
Logstash default install strictly searches for a single logstash.conf file. It is possible to change this to align with other documentation you may reference. Personally, I am sticking with the single configuration pipeline file so that debugging is easier.
**NOTE:** The logstash pipeline is a major configuration point. I recommend saving copies of this file prior to editing.
1. Edit logstash.conf: `ee /usr/local/etc/logstash/logstash.conf`
2. Paste the following configuration found in [logstash.conf](logstash.conf), as needed.
3. 5. Save and Exit the file editor.
4. Copy the [pfsense grok file](https://github.com/a3ilson/pfelk) into `/usr/local/etc/logstash/patterns`
5. Start Logstash: `service logstash start` and make sure it's stable for ~10 seconds.

## Logstash Plugins (built in)
### GeoIP
Logstash already has the GeoIP plugin installed in version 5.3. All it needs are the flat file databases to geolocate an IP address. Supposedly, the `geoipupdate` port will support this, but it only seems to download legacy DAT files instead of the current, more compatible MMDB files.
```shell
cd /usr/ports/net/geoipupdate/ && make install clean
```
**Alternative:** download the MMDB files without any special script using my [geoupdate-custom.sh](geoipupdate-custom.sh).

**Note:** `geoipudate` port does follows the FreeBSD /usr/local/share/GeoIP and not the Linux /usr/share/GeoIP path. My custom script is set designed to extract the files to wherever the file is locally executed from.

No matter which path taken, be sure to update the files regularly. A simple crontab like the one below written to a file is sufficient. Remove the path you don't need to minimize load.
```shell
# top of crontab

28 7 * * 5 /usr/local/bin/geoipupdate
28 7 * * 5 /usr/local/share/GeoIP/geoipupdate-custom.sh
# end of crontab
```

## Logstash Plugins (install required)
**IMPORTANT:** The Logstash-plugin installer may not be executable by default. Also, the linux documented directory is inaccurate for FreeBSD. Run the following command to add execution permissions to logstash-plugin installer before proceeding.
```shell
chmod 744 /usr/local/logstash/bin/logstash-plugin
```

### Translate Filter
```shell
/usr/local/share/logstash/bin/logstash-plugin install logstash-filter-translate
```
The [extelligenceblog.it](https://extelligenceblog.it/2017/07/23/elastic-stack-suricata-idps-and-pfsense-firewall-part-3-logstash-pipeline-additions-suricata-alerts/) does a great bit on covering this 2/3 of the way down the page and even provides a [CSV dictionary](http://extelligenceblog.it/wp-content/uploads/2017/07/service-names-port-numbers.csv).

## Configure Kibana
1. Create and edit kibana.yml: `ee /usr/local/etc/kibana.yml`
2. Paste the following configuration found in [kibana.yml](kibana.yml), as needed.
3. Save and Exit the file editor.
4. Start Kibana: `service kibana start`

## Configuration Nginx (skip if installing X-Pack)
1. Edit nginx.conf: `ee /usr/local/etc/nginx/nginx.conf`
2. Create a vhost using the following config:
```
server {
  server_name kibana.foo.bar;
  listen 80;
  proxy_set_header Host             $host;
  proxy_set_header X-Real-IP        $remote_addr;
  proxy_set_header X-Forwarded-For  $proxy_add_x_forwarded_for;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
  proxy_set_header Cookie "";

  location / {
    auth_basic "Kibana Login";
    auth_basic_user_file "/usr/local/etc/nginx/kibana.htpasswd";
    proxy_pass http://127.0.0.1:5602;
    proxy_http_version 1.1;
  }
}
```
**NOTE:** `kibana.foo.bar` should reflect your FQDN.

**NOTE:** To disable Access Control, comment out or remove the auth_basic lines from the configuration above. Additionally, skip the next step as no password file needs to be generated.

3. Generate the password file. Fill in the `[username]` and `[SuperSecretPassword]`
```shell
python2.7 /usr/local/bin/htpasswd.py -c -b /usr/local/etc/nginx/kibana.htpasswd [username] [SuperSecretPassword]
```
4. Start Nginx: `service nginx start`

### Install X-Pack (incomplete)
Given the unsupported nature of ElasticSearch on FreeBSD, it is recommended to establish a working installation prior to installing additional plugins. The commands below assume that elasticsearch and kibana are already working properly. Skipping nginx installation above means that *server.host* in the *kibana.yml* file must be changed to reflect the host's IP.

1. Register for an Elastic Subscription. Copy the subscription JSON file to the server to run in the shell script below.
2. Run the following script. Update *"kibanapassword* and *logstashpassword* before use.
```shell
service elasticsearch stop
service kibana stop
cd /usr/ports/textproc/elasticsearch5-x-pack/ && make install clean
cd /usr/ports/textproc/kibana5-x-pack/ && make install clean
printf '# Allow X-Pack features to run (unsupported) in FreeBSD\nxpack.ml.enabled: false' > /usr/local/etc/elasticsearch/elasticsearch.yml
printf 'elasticsearch.password: kibanapassword' > /usr/local/etc/kibana.yml
printf 'xpack.monitoring.elasticsearch.password: logstashpassword' > /usr/local/logstash/config/logstash.yml
service elasticsearch start
service kibana start
sleep 5
service elasticsearch status
service kibana status
```
3. If ElasticSearch and Kibana come back properly, use a web browser to navigate to the kibana login page. Default username is *elastic* and default password is *changeme*.
4. In the left menu bar, click *Management* => *Users* to update the Elastic superuser's password as well as update the kibana, and logstash_system passwords from the previous shell script. Return to the shell.
5. In the shell, run the following commands to install the license and purge the old kibana index
```shell
curl -XPUT -u elastic 'http://127.0.0.1:9100/_xpack/license' -H "Content-Type: application/json" -d @/usr/local/etc/elasticsearch/license.json
curl -XDELETE http://localhost:9100/.kibana
```
6. *To do: figure out how to install X-Pack for LogStash*

## Install Filebeat agent

### On pfsense 2.4.x [(the detailed version)](https://extelligenceblog.it/2017/07/11/elastic-stack-suricata-idps-and-pfsense-firewall-part-1/)
1. Log into the web interface. Navigate to Suricata.
   * Enable *EVE JSON log*
   * Set *EVE Output Type* to *FILE*
   * Enable (at the very least) under EVE Logged Info: **Alerts** and **Suricata will log additional payload data with alerts**
   * Save this configuration
2. Log into pfsense and add the latest Filebeat pkg. Use the latest `beats-[version].txz`
```shell
pkg add http://pkg.freebsd.org/FreeBSD:11:amd64/latest/All/ *beats-[version].txz*
```
