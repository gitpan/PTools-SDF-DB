#!/opt/perl/bin/perl -w
#
# File:  sdfDbutil.pl
# Desc:  Query/Update/Add utility for the "simple data base system" (SDF DB)
# Date:  Thu Jul 18 18:03:09 2002
#
# Usage:
#        dbutil.pl -h
#
# Abstract:
#        This script uses a module that is a proof-of-concept to demonstrate 
#        various methods using an SDB Abstraction Module "PTools::SDF::DBUtil".
#
#        Notice that no data base, data set or data field information is
#        hard-coded in the DBUtil class. All prompts, field edits, data 
#        entry "hints" and default values are obtained using SDBMS calls.
#
 use Cwd;
 use File::Basename;
 BEGIN {   # Works on many systems. See "www.ccobb.net/ptools/"
   my($xyz,$bin) = fileparse( $0 );     # my($curDir) = getcwd;
   chdir( "$bin/.." );     my($app,$top) = fileparse( getcwd ); 
   chop( $top );                        #     chdir( $curDir );
   $ENV{'PTOOLS_TOPDIR'} = $top;  $ENV{'PTOOLS_APPDIR'} = $app;
 } #-----------------------------------------------------------
 use lib "$ENV{'PTOOLS_TOPDIR'}/$ENV{'PTOOLS_APPDIR'}/lib";
 use strict;

 use PTools::Global;
 use PTools::SDF::DBUtil;

 my $status = run PTools::SDF::DBUtil( { DefaultBase => "DemoDB" } );

 exit( $status ? 1 : 0 );
