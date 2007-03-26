# -*- Perl -*-
#
# File:  PTools/SDF/RPC/DemoDB.pm
# Desc:  Light client for remote access to PTools::SDF::DemoDB data files
# Date:  Tue Nov 19 18:47:09 2002
#

package PTools::SDF::RPC::DemoDB;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA $AUTOLOAD );
 $VERSION = '0.03';
#@ISA     = qw(  );

 use RPC::PlClient;

 my $RemoteDB   = "PTools::SDF::DemoDB";  # the "real" data base class
 my $RemoteHost = 'localhost';            # the remote server name
 my $RemotePort = 1234;                   # the remote server port

sub new
{   my($class,@args) = @_;

    my $self = bless {}, ref($class)||$class;

    my $clientObj = RPC::PlClient->new(
         'peeraddr'    => $RemoteHost,                  # configure above
         'peerport'    => $RemotePort,                  # configure above
         'application' => 'PTools::SDF::RPC::DBServer', # use THIS value
         'version'     => '0.01',
         'user'        => '',
         'password'    => '',
                 );

    my $dbObj = $clientObj->ClientObject( $RemoteDB, 'new', @args);

    $@ and die "An error occurred: $@";

    $self->{dbObj} = $dbObj;

    return $self;
}

sub dset
{   my($self,@args) = @_;

    my $clientObj = RPC::PlClient->new(
         'peeraddr'    => $RemoteHost,
         'peerport'    => $RemotePort,
         'application' => 'PTools::SDF::RPC::DBServer',
         'version'     => '0.01',
         'user'        => '',
         'password'    => '',
                 );

    my $dsetObj = $clientObj->ClientObject( $RemoteDB, 'dset', @args);

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

