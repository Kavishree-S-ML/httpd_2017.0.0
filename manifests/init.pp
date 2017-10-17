#!/bin/bash
# CALL THE PARAMETER FILE
include ::httpd::params
class httpd (
  $httpd_port                                               = $::httpd::params::httpd_port,
) inherits ::httpd::params {
  # EXECUTE 'YUM UPDATE'
  exec { 'yum':                       # exec resource named 'yum update'
    command => 'sudo yum -y update',  # command this resource will run
    path => ['/usr/bin'],
    logoutput => true,
    returns => [0,1],
  }
   
   #CHECK FOR THE EXISTENCE HTML DIRECTORY, IF NOT THERE THEN CREATE THE DIRECTORY
   file{ '/var/www/':   #add a second file resource declaration. This one creates a directory /var/www/ for our web server
     ensure  =>  directory,
     mode    =>  "0777",
   }

   file{ '/var/www/httpserver/':   #add a second file resource declaration. This one creates a directory /var/www/httpserver/ for our web server
     ensure  =>  directory,
     mode    =>  "0777",
   }
   
   #CREATE THE HTML FILE FOR HTTPD WEB SERVER
   file{ '/var/www/httpserver/index.html':
     ensure  =>  file,
     mode    => "0755",
     content =>  template("httpd/index_config.html"),
     require => File["/var/www/httpserver/"],
   }
     
  # CONFIGURING THE FIREWALL
  #The web server requires an open port so people can access the pages hosted on our web server. 
  #The open problem is that different versions of Red Hat Enterprise Linux uses different methods for controlling the firewall. 
  #For Red Hat Enterprise Linux 6 and below, we use iptables. 
  #For Red Hat Enterprise Linux 7, we use firewalld
  #Use the operatingsystemmajrelease fact to determine whether the operating system is Red Hat Enterprise Linux 6 or 7.
  if $operatingsystemrelease =~ /^7.*/ {
    #RUNS FIREWALL-CMD TO ADD A PERMANENT FIREWALL RULE
    exec { 'firewall-cmd':
      command => "firewall-cmd --zone=public --add-port=${httpd_port}/tcp --permanent",
      path => ['/usr/bin'],
      logoutput => true,
      notify => Service["firewalld"],  #checks our firewall for any changes. If it changed, Puppet restarts the service
    }

    #RESTART THE FIREWALLD SERVICE
    service { 'firewalld':
      ensure => running,
    }
  }elsif $operatingsystemrelease =~ /^6.*/ {
    #RUNS IPTABLES-CMD TO ADD A PERMANENT FIREWALL RULE 
    exec { 'iptables':
      command => "iptables -I INPUT 1 -p tcp -m multiport --ports ${httpd_port} -m comment --comment 'Custom HTTP Web Host' -j ACCEPT &amp;&amp; iptables-save > /etc/sysconfig/iptables",
      path => ['/sbin'],
      logoutput => true,
      notify => Service["iptables"],  #checks our firewall for any changes. If it changed, Puppet restarts the service
    }

    #RESTART THE FIREWALLD SERVICE
    service { 'iptables':
      ensure => running,
    }
  }  
  
  # CONFIGURING SELINUX
  #SELinux restricts non-standard access to the HTTP server by default. 
  #If we define a custom port, we need to add configuration that allows SELinux to grant access.
  #Puppet contains resource types to manage some SELinux functions, such as Booleans and modules. 
  #However, we need to execute the semanage command to manage port settings. 
  #This tool is a part of the policycoreutils-python package, which is not installed on Red Hat Enterprise Linux systems by default.
  
  #ADD THE CUSTOM PORT TO THE LIST OF TCP PORTS, THAT APACHE IS ALLOWED TO LISTEN ON
  exec { 'semanage-port':
    command => "semanage port -a -t http_port_t -p tcp ${httpd_port}",
    path => "/usr/sbin",
    require => Package['policycoreutils-python'],  #makes sure the policycoreutils-python is installed prior to executing the command
    logoutput => true,
    returns => [0,1],
  }
  
  # INSTALL SEMANAGE PACKAGE TO ADD THE PORT IN SELINUX
  package { 'policycoreutils-python':
    ensure => installed,
  }

  # INSTALLING A HTTP SERVER
   package { 'httpd':
     ensure => installed,
     name   => httpd,
   }
   
   # CONFIGURING THE HTTP SERVER
   # CONFIGURE THE HTTPD.CONF FILE WITH THE CORRESPONDING LISTENING PORT
   file { '/etc/httpd/conf/httpd.conf':
     notify => Service["httpd"],    #checks our configuration file for any changes. If the file has changed, Puppet restarts the service
     ensure => file,
     require => Package["httpd"],   #check the httpd package is installed before adding this file
     content => template("httpd/httpd.conf.erb"),
   }
  
   # RUNNING THE HTTP SERVER
   #After installing the httpd package, we start the service using another resource declaration: service
   service { 'httpd':
     ensure => running,            #checks if the service is running. If not, Puppet starts it
     enable => true,               #sets the service to run when the system boots
     require => Package["httpd"],  #ensures the httpd service starts after the httpd package installs
   }
}
