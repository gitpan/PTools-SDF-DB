# -*- Perl -*-
#
# File:  PTools/SDF/DBClient.pm
# Desc:  Generic Local/Remote client for "Simple Data Bases" (SDF DB)
# Date:  Thu Apr 17 09:10:07 2003
# Stat:  Prototype
#
# Usage:
#        package ApplicationDBClient;
#        @ISA = qw( PTools::SDF::DBClient );
#        use PTools::SDF::DBClient qw( LocalAccessClass RemoteAccessClass );
#
#   Then using the Application access module, as shown next, will
#   allow access to the Appliation Data Base. The client script
#   creates the $DB object and does not care if the data files 
#   reside on a local or remote note. For those times when it is
#   interesting to know if the access is local or remote client
#   scripts can call the "serverType" method on a $DB object.
#
#        #!/opt/perl/bin/perl -w
#        use ApplicationDBClient;
#        $DB = new ApplicationDBClient;
#        $DataSet = $DB->dataSet( "dataSetName" );
#
package PTools::SDF::DBClient;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.04';
#@ISA     = qw(  );              # determine inheritance at run-time

 use PTools::Loader;             # demand load Perl modules at run-time

 my($LocalClass,$RemoteClass);   # set classes in "import" method call
 my $ServerType = "unknown";     # set to "local" or "remote" in "new"

sub serverType { $ServerType }

sub setErr { return( $_[0]->{STATUS}=$_[1]||0, $_[0]->{ERROR}=$_[2]||"" ) }
sub status { return( $_[0]->{STATUS}||0, $_[0]->{ERROR}||"" )             }
sub stat   { ( wantarray ? ($_[0]->{ERROR}||"") : ($_[0]->{STATUS} ||0) ) }
sub err    { return($_[0]->{ERROR}||"")                                   }

sub import
{   my($class,@args) = @_;
    return if ($#args == -1 and $LocalClass and $RemoteClass);
    if ($#args != 1) {
	my($pack,$file,$line)=caller();
	warn "Usage:  use $PACK qw( LocalClass RemoteClass );\n";
	die  "Called by $pack at line $line in file\n$file\nabort";
    }
    ($LocalClass, $RemoteClass) = @args;

    my($dbClass, @error);

    my $generr = PTools::Loader->generror; # save current abort setting
    PTools::Loader->noabort;               # do not abort if Loader fails

    ($dbClass, $ServerType) = ($LocalClass, "local");
    (@error) = PTools::Loader->use( $dbClass );

    if ($error[0]) {
	(@error) = PTools::Loader->use( "Storable" );
	PTools::Loader->abort( @error );           # abort if error
	$Storable::forgive_me = 1;         # avoid "Segmentation fault" errs

	($dbClass, $ServerType) = ($RemoteClass, "remote");
	(@error) = PTools::Loader->use( $dbClass );
	PTools::Loader->abort( @error );   # abort if error
    }
    PTools::Loader->generror( $generr );   # restore prior abort setting

    push @ISA, $dbClass;            # determine inheritance at run-time

    #
    # Note:
    # This module relies on a "failure to load" the "$LocalClass" module
    # (class) to determine when the data base resides on a remote server. 
    # When testing this module make _sure_ you know what modules reside 
    # in what "lib paths" on "cmd-line host" AND "web host." Otherwise,
    # it may appear that this module is broken.
    #
    # It could be that the "$LocalDBClient" class was found in
    # an unexpected location. Use the "Global->dump" example,
    # below, to check which "DB" modules are currently loaded.
    # 
   ## use Global;              # PerlTools Global variables/methods
   ## print "Content-type: text/plain\n\n" if Global->param('cgi');
   ## print Global->dump('inclib');           # DEBUG
   ## #print "DEBUG: dbClass='$dbClass'\n";

    return;
}

sub new
{   my($class,@args) = @_;
    #
    # The "RPC::PlClient" class is a great idea but a poor implementation.
    # It writes to STDERR when it can't connect to an "RPC::PlServer".
    #
    # Workaround: 
    # We must wrap the instantiation of "$self" with an "eval" so we
    # can check for failure and set an error state prior to return.
    #
    my($self,$stat,$err) = ("",0,"");

    #warn "DEBUG: about to instantiate\n";

    eval "\$self = $PACK->SUPER::new( @args )";

    ##warn "DEBUG: instantiate complete\n";
    ## die "DEBUG: self='$self'  \$@='$@'\n";

    if ($@) {
	if ($@ =~ m#^Cannot connect: Connection refused#) {
	    $err = "Connection refused; is server running?";
	} elsif ($@ =~ m#Unexpected EOF from server#) {
	    $err = "Connection denied; is client authorized?";
	} else {
	    $err = $@;
	}
	bless $self = {}, ref($class)||$class;
	$stat = -1;
	$self->setErr($stat, $err);
    }
    #warn "DEBUG: instantiate complete\n";

    return( $self ) unless wantarray;
    return( $self, $stat, $err );
}
#_________________________
1; # Required by require()
