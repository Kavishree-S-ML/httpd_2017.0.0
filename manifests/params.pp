# Class: httpd::params
#
# This class manages Apache-httpd parameters
#
# Parameters:
# - The $httpd_port is the port number under which the httpd server have to run

class httpd::params {
        $httpd_port                       = '2009'
}
