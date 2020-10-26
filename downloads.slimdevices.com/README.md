# Logitech Media Server Update Check on downloads.slimdevices.com

## `index.php` - render the nightly download page

The file `index.php` would search the sub-folders of where it's stored for packages. It collects the data of the latest versions it finds and provides a download page (see http://downloads.slimdevices.com/nightly/) for the various versions and platforms.

With the additional `xml=1` parameter it can render a machine readable XML file. Eg. http://downloads.slimdevices.com/nightly/index.php?ver=8.0&xml=1.

## LMS Update Check

Logitech Media Server (LMS) versions 7.9 and later can use an XML file to find new server versions. This file would have information about the latest builds for the various platforms. It corresponds to the output of above `index.php` with the additional `xml=1` parameter.

As LMS expects the URL to the repository file to be an absolute path without any parameter, eg. `/nightly/8.0.0/servers.xml` I added some rewrite rules in `.htaccess` to map such URLs to the avorementioned dynamic URLs.

The additional `latest.xml` points to the latest stable release.

