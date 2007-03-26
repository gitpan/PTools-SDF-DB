# -*- Perl -*-
#
# File:  PTools/SDF/RPC/DemoDBServer.pm
# Desc:  A lightweight server for remote access to an SDF "data base"
# Date:  Tue Nov 19 18:47:09 2002
# Stat:  Prototype, Experimental
#
# Abstract:
#        This class is the concrete implementation of the
#        abstract "PTools::SDF::RPC::DBServer" class.
#        Blah, blah, blah ...
#

package PTools::SDF::RPC::DemoDBServer;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.02';
 @ISA     = qw( PTools::SDF::RPC::DBServer ); # Defines interitance 

 use PTools::SDF::RPC::DBServer;      # ISA RPC::PlServer, ISA Net::Daemon

 # The following class is the "real" SDF data base that we will
 # enable for remote access via the "PTools::SDF::RPC::DemoDB" client.
 # This must also be specified in the "_config" method, below.

 use PTools::SDF::DemoDB;

 my $LocalDB    = "PTools::SDF::DemoDB";      # the "real data base" class
 my $WritePerms = 0;                          # 0 = disallow write access


sub run
{   my($class,$hashRef) = @_;
    #
    # WARN: Only a portion of the required configuration parameters
    # are defined here. The remaining params are defined in the
    # abstract base class "PTools::SDF::RPC::DBServer". 
    # See also "RPC::PlServer"
    #
    $hashRef ||= $class->_config( $hashRef );

    #print "calling 'run':  hashRef='$hashRef'  in '$PACK'\n";

    $PACK->SUPER::run( $hashRef );
}

sub _config
{   my($class) = @_;

    my $PidFile = "/dev/null";
    my $LogFile = "/dev/tty";

    return({
	  'SDF_DB_CLASS' => $LocalDB,         # the "real data base" class
	  'SDF_DB_WRITE' => $WritePerms,      # 0 = disallow write access

            'pidfile'    => $PidFile,
            'logfile'    => $LogFile,
            'facility'   => 'daemon',         # Default 'facility'
          # 'user'       => 'vobadm',
          # 'group'      => 'nobody',
            'localport'  => 1234,
            'mode'       => 'fork',           # Recommended for Unix
            'clients' => [
                # Accept the local
                #{
                #    'mask' => '^192\.168\.1\.\d+$',
                #    'accept' => 1,
                #},
                # Accept myhost.company.com
                {
                   #'mask' => '^(rossini)\.cup.hp\.com$',
                    'mask' => '^(illinois|localhost)(\.cup.hp\.com)?$',
                   #'mask' => '.*',
                    'accept' => 1,
		  # 'users' => [ 
		  #	{ 'name'    => 'root', },  #' cypher' => $connectKey, },
		  #	      ],
                },
                # Deny everything else
                {
                    'mask' => '.*',
                    'accept' => 0,
                },
            ],
          });
}
#_________________________
1; # Required by require()

__END__

# ToDo: Add "POD" template here for "manpage" documentation.

