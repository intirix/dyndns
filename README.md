# dyndns
Perl CGI script for creating a dynamic DNS system

Configuration

Most of the configuration is stored in a master properties file.
By default, the dyndns will look for the file at /opt/dyndns/config/dyndns.properties.  This file contains some basic configuration information as well as the path to other config files.

Authentication

Dyndns does not provide authentication.  It is the responsibility of the system administrator to protected the system with Basic Authentication.

Authorization

One of the config files that is used is a CSV file that contains a list of domain names that are managed.  One of the columns is a semi-colon separated list of users who have access to update that domain.  To give someone access, make sure that they are part of the authentication system and that their username is listed for all the domains that they should be able to update
