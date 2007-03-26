# -*- Perl -*-
#
# File:  PTools/SDF/RPC/DBClient.pm
# Desc:  Generic Remote access client for "Simple Data Bases" (SDF DB)
# Auth:  Chris Cobb, Hewlett-Packard Co., Cupertino, CA <cobb@cup.hp.com>
# Date:  Thu Apr 17 09:10:07 2003
#
# Usage:
#        package RPC::ApplicationDB;
#        use vars qw ( $LocalAccessClass $ConfigHashRef );
#        @ISA = qw( PTools::SDF::RPC::DBClient );
#
#        BEGIN {
#            $LocalAccessClass = "ApplicationDB";
#            $ConfigRef = {
#                 'peeraddr'   => 'localhost',   # remote SDF DB server
#                 'maxmessage' => 5120000,       # limits data file to 5MB
#                 'peerport'   => 1234,
#                 'version'    => '0.01',
#                 'user'       => '',
#                 'password'   => '',
#            };
#        }
#        use PTools::SDF::RPC::DBClient qw( $LocalAccessClass $ConfigHashRef );
#
#   Then using the Application access module, as shown next, allows
#   remote access to the Appliation Data Base. The client script
#   creates the $DB object and does not care if the data files 
#   reside on a local or remote note. For those times when it is
#   interesting to know if the access is local or remote client
#   scripts can call the "serverType" method on a $DB object.
#
#        #!/opt/perl/bin/perl -w
#        use RPC::ApplicationDB;
#        $DB = new RPC::ApplicationDB;
#
#   And now the application can use the "$DB" object exactly as if it
#   were accessing local data files. (Some restrictions may apply -- it
#   is possible to deny access to various methods such as "lock" and 
#   "save" on the server side of the connection.)
#
#   See the man page for this module for an example of implementing
#   this as a subclass that creates "singleton" objects.
#
package PTools::SDF::RPC::DBClient;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA $AUTOLOAD );
 $VERSION = '0.05';
#@ISA     = qw( );               # This is a 'factory' class that returns
                                 # 'client' objects that LOOK (well "ACT")
                                 # like what the calling script expects...
 use RPC::PlClient;

 my($LocalClass, $ConfigHashRef);


sub import
{   my($class,@args) = @_;
    return if ($#args == -1 and $LocalClass and $ConfigHashRef);
    if ( ($#args != 1) or (! ref($args[1])) ) {
        my($pack,$file,$line)=caller();
        warn "Usage:  use $PACK qw( LocalClass ConfigHashRef );\n";
        die  "Called by $pack at line $line in file\n$file\nabort";
    }
    ($LocalClass, $ConfigHashRef) = @args;

    # The "application" name passed to the RPC::PlClient 'new' method
    # is always the same (in the SDF DB client/server setup), so just
    # force "the right thing" here.
    #
    $ConfigHashRef->{application} = 'PTools::SDF::RPC::DBServer';

    # print "DEBUG: LocalClass='$LocalClass' Config='$ConfigHashRef'\n";
    return;
}

sub new
{   my($class,@args) = @_;

    my $self = bless {}, ref($class)||$class;

    $ConfigHashRef->{'TMP_DEBUG'} = $LocalClass ."::new()";

    my $clientObj = RPC::PlClient->new( %$ConfigHashRef );

    my $dbObj = $clientObj->ClientObject($LocalClass, 'new', @args);

    $@ and die "An error occurred: $@";

    $self->{dbObj} = $dbObj;                 # cache DB in $self ... then

    return $self;
}

   # WARN: Any and all alises for the "dataSet" method defined in the 
   #       class "PTools::SDF::DB" _must_ also be defined here or they will
   #       not be recoginized as valid when using PlServer for RPC access.

   *openDataSet = \&dataSet;
   *dset        = \&dataSet;
   *dataset     = \&dataSet;
   *datafile    = \&dataSet;
   *dataFile    = \&dataSet;

sub dataSet
{   my($self,$dset,@args) = @_;

    $ConfigHashRef->{'TMP_DEBUG'} = $LocalClass ."::dset()";

    my $clientObj = RPC::PlClient->new( %$ConfigHashRef );

    my $dsetObj = $clientObj->ClientObject( $LocalClass, 'dset', $dset,@args);

    $@ and die "An error occurred: $@";

    return $dsetObj;
}

sub AUTOLOAD
{   my($self,@args) = @_;

    my($method) = $AUTOLOAD =~ /::(\w+)$/ or die "No such method: $AUTOLOAD";

    return unless defined $self->{dbObj};

    ###my $dbObj = $self->{dbObj} || die "No 'dbObj' found in AUTOLOAD.";
    ###print "AUTOLOAD method='$method(@args)' on $dbObj\n";

    return $self->{dbObj}->$method( @args );
}
#_________________________
1; # Required by require()

__END__

# ToDo: Add "POD" template here for "manpage" documentation.

