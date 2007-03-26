# -*- Perl -*-
#
# File:  PTools/SDF/DemoDBClient.pm
# Desc:  Local/Remote access class for the Demo SDF "Data Base"
# Date:  Mon Apr 17 10:36:28 2003
# Stat:  Prototype
#
# Usage:
#        use PTools::SDF::DemoDBClient;
#        $DB = new PTools::SDF::DemoDBClient;
#
#   At this point the "$DB" object may access DB data files on
#   either a local or remote host. Client scripts need not care.
#   Note, however, that write access may be disbled by the remote
#   DB Server. If so, the "lock" method will also fail. A client
#   script should successfully obtain a lock on a "$DB" object 
#   prior to calling the "save" method on a "$DataSet" object.
#
package PTools::SDF::DemoDBClient;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.01';
 @ISA     = qw( PTools::SDF::DBClient );

 use PTools::SDF::DBClient qw( PTools::SDF::DemoDB  PTools::SDF::RPC::DemoDB );
#_________________________
1; # Required by require()
