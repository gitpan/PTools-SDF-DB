# -*- Perl -*-
#
# File:  PTools/SDF/DB.pm
# Desc:  Base Class to manage ascii file "data sets" as a simple data base
# Date:  Thu Jun 27 09:36:05 2002
# Stat:  Prototype
#
# Abstract:
#        This module manipulates a simplistic data base "schema" format.
#        The "schema" is just a simple Perl data structure. The real
#        work is done by the "PTools::SDF::DSET" class, which is a wrapper 
#        for each of the "data sets" defined in the "data base."
#
#        This is an "abstract" class and, as such, is not intended for
#        use directly. A subclass must be created, as shown in the
#        Synopsis, that defines the schema for the "data base."
#
#        See ___ for a description of the SDF DB Schema format.
#
# Synopsis:
#
#        package PTools::SDF::TestDB;
#        use strict;
#
#        my $PACK = __PACKAGE__;
#        use vars qw( $VERSION @ISA );
#        $VERSION = '0.01';
#        @ISA     = qw( PTools::SDF::DB );
#
#        use PTools::Local;
#        use PTools::SDF::DB;
#
#        sub new { }
#        sub loadSchema {}      # define SDF DB "Schema"
#

package PTools::SDF::DB;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.08';
#@ISA     = qw( );

#use PTools::Local;
 use PTools::SDF::DBPolicy;
 use PTools::SDF::DSET;
 use PTools::SDF::Lock::Advisory;
 use PTools::String;        # misc string functions, including "prompt"

 my $DataSetClass = "PTools::SDF::DSET";
 my $PolicyClass  = "PTools::SDF::DBPolicy";
 my $LockClass    = "PTools::SDF::Lock::Advisory";
 my $ServerType   = "local";  # assume DB is "local" by default


sub new    { bless {}, ref($_[0])||$_[0] }
sub setErr { return( $_[0]->{_STATUS}=$_[1]||0, $_[0]->{_ERROR}=$_[2]||"" ) }
sub status { return( $_[0]->{_STATUS}||0, $_[0]->{_ERROR}||"" )             }
sub stat   { ( wantarray ? ($_[0]->{_ERROR}||"") : ($_[0]->{_STATUS} ||0) ) }
sub err    { return($_[0]->{_ERROR}||"")                                    }

#_______________________________________________________________________
# Data Base Information
#
no strict "refs";

   *dbaseName   = \&dataBaseName;
   *baseName    = \&dataBaseName;

   *dataSetList = \&dataSetNames;
   *dsetList    = \&dataSetNames;
   *dsetNames   = \&dataSetNames;

   *dsetKeys    = \&dataSetKeys;


#ub schemaName     {    $_[0]->{SchemaName}  ||""         }    # OBSOLETE
#ub schemaFile     {    $_[0]->{_schemaFile} ||""         }    # OBSOLETE

sub serverType     {    $ServerType                       }    # local/remote
sub schemaVersion  {    $_[0]->{Schema} ||""              }
sub dataBaseName   {    $_[0]->{DataBase}->{BaseName} ||""}
sub dataSetNames   { sort keys %{ $_[0]->{DataSet} }      }
sub dataBaseSchema {    $_[0]->{DataBase}                 }
sub dataSetSchema  {    $_[0]->{DataSet}->{$_[1]||""}     }
sub primarySetList { @{ $_[0]->{DataBase}->{PriDataSet} } }
sub dataBaseFile   {    $_[0]->{DataBase}->{DataFile} ||""}
sub dataBaseLock   {    $_[0]->{DataBase}->{DataFile} ||""}

#_______________________________________________________________________
# Data Set Information
#
   *dsetFile    = \&dataSetFile;
   *dsetLock    = \&dataSetLock;
   *dsetTitle   = \&dataSetTitle;
   *dsetKeys    = \&dataSetKeys;
   *dsetFields  = \&dataSetFields;
   *dsetAliases = \&dataSetAliases;
   *dsetName    = \&dataSetName;

sub dataSetFile    {    $_[0]->{DataSet}->{$_[1]||""}->{DataFile}||""   }
sub dataSetLock    {    $_[0]->{DataSet}->{$_[1]||""}->{DataFile}||""   }
sub dataSetTitle   {    $_[0]->{DataSet}->{$_[1]||""}->{Title}   ||""   }
sub dataSetKeys    { @{ $_[0]->{DataSet}->{$_[1]||""}->{Keys}    ||"" } }
sub dataSetFields  { @{ $_[0]->{DataSet}->{$_[1]||""}->{Fields}  ||"" } }
sub getEditPolicy  {    $_[0]->{DataSet}->{$_[1]||""}->{Policy}  ||""   }

#  dataSetAliases  - return list of aliases for a particular data set
#                     (@aliasList) = $DB->dataSetAliases;
#
#  fullAliasList   - return complete list of aliases for all data sets
#                     (@fullAliasList) = $DB->fullAliasList;
#
#  dataSetName     - convert data set alias name to "real" data set name
#                      $dataSetName = $DB->dataSetName( $aliasName );

sub dataSetAliases { @{ $_[0]->{DataSet}->{$_[1]||""}->{Aliases} ||"" } }
sub fullAliasList  { sort keys %{ $_[0]->{_dataSetAlias} }              }
sub dataSetName    {    $_[0]->{_dataSetAlias}->{$_[1]}          ||""   }

#_______________________________________________________________________
# Data Set Field Information
#
   *fieldPrompt = \&fieldText;

sub fieldText {$_[0]->{DataSet}->{$_[1]||""}->{Field}->{Text}->{$_[2]||""}||""}
sub fieldEdit {$_[0]->{DataSet}->{$_[1]||""}->{Field}->{Edit}->{$_[2]||""}||""}
sub fieldHint {$_[0]->{DataSet}->{$_[1]||""}->{Field}->{Hint}->{$_[2]||""}||""}

use strict "refs";
#_______________________________________________________________________

# Allow any of the subclass modules to invoke the String->prompt
# used to prompt user and perform rudimentary data input edits.

   *promptUser = \&prompt;

sub prompt { shift; return String->prompt( @_ ) }


# Note: Make the lock/unlock look just like other SDF::<module> classes
#       (at least as much as possible).

sub isLocked  { return $_[0]->{_lockObj} ? $_[0]->{_lockObj}->isLocked  : "0" }
sub notLocked { return $_[0]->{_lockObj} ? $_[0]->{_lockObj}->notLocked : "1" }

  *advisoryLock   = \&lock;
  *advisoryUnlock = \&unlock;

sub lock
{   my($self,$fileName,@params) = @_;

    ref $self or return( $self->setErr(-1,"Must call 'lock' as object method"));

    $self->{_lockObj} ||= $LockClass->new;

    return if $self->{_lockObj}->isLocked;    # already locked

    $fileName ||= $self->dataBaseLock;
    $fileName || die "No 'fileName' found to lock";

 #  print "DEBUG: attempting to lock '$fileName'\n";

 #  unless ($fileName =~ m#^/#) {
 #	$fileName = PTools::Local->path('app_datdir', $fileName);
 #  }
 ## die "lock: fileName='$fileName'\n";

    if (! $fileName) {
	return $self->setErr(-1,"Unable to determine lock file name in $PACK");
    }

    my($stat,$err) = $self->{_lockObj}->lock( $fileName, @params );

    if ($stat) {
	return $self->setErr( $stat, $err );
    } elsif ( $self->{_lockObj}->isLocked ) {
	$self->{_dataBaseLock} = 1;
	return;
    } else {
	return $self->setErr(-1, "Unknown failure in 'lock' method of '$PACK'");
    }
    return;
}

sub unlock  
{   my($self,@params) = @_;

    # Note that any lock is released if/when "_lockObj" falls out of scope
    # (assuming that "_lockObj" ISA "PTools::SDF::Lock::Advisory" object) which 
    # implies that if the current object of THIS class falls out of scope
    # any lock is also released.

    $self->{_lockObj} || die "Expected 'lock object' not found here";

    my($stat,$err) = $self->{_lockObj}->unlock;

    $stat and $self->setErr( $stat,$err );
    $stat  or $self->{_dataBaseLock} = 0;

    return;
}

   *openDataSet = \&dataSet;
   *dset        = \&dataSet;
   *dataset     = \&dataSet;
   *datafile    = \&dataSet;
   *dataFile    = \&dataSet;

sub dataSet
{   my($self,$dataSetName,@params) = @_;

    #return undef unless ref $self;
    #
    # Here we allow for RPC access ...
    # 
    ref $self or ( $self = $self->new );
    #_______________________________________

    return undef unless $dataSetName;

    return undef unless $DataSetClass;

    $self->initialize unless defined $self->{_openDataSets};
    #______________________________________________________
    # First check to see if we have an alias name here.
    # Then determine if we've already opened this data set.
    #
    $dataSetName = $self->{_dataSetAlias}->{$dataSetName}
    	if defined $self->{_dataSetAlias}->{$dataSetName};

    return $self->{_openDataSets}->{$dataSetName}
    	if defined $self->{_openDataSets}->{$dataSetName};

    #______________________________________________________
    # Nope, this is first access ... open up the data set.
    # Data set instantiation will initialize any primary keys.
    # Also pass along portions of the schema that are pertinent 
    # to this particular data set.
    #
    my $dataSetFile = $self->dataSetFile( $dataSetName );
    $dataSetFile or die "No 'dataSetFile' found for '$dataSetName'";

    my (@dataFields) = $self->dataSetFields( $dataSetName );

    my $schema  = {  DataBase => $self->dataBaseSchema,
	              DataSet => $self->dataSetSchema( $dataSetName ),
		  };

    my $dataSetObj  = 
	$DataSetClass->new( $dataSetFile, $schema, \@dataFields, @params);

    my($stat,$err)  = $dataSetObj->status;

    ($stat and ! $dataSetObj) and die $err;

    return undef unless $dataSetObj;

    $self->{_openDataSets}->{$dataSetName} = $dataSetObj;

    return $dataSetObj;
}

sub initialize
{   my($self) = @_;

    $self->{_openDataSets} = {};
    $self->{_dataBaseLock} = 0;
    $self->{_dataSetAlias} = {};
  # $self->{_lockObj}      = $LockClass->new;
    $self->{_policyObj}    = $PolicyClass->new( $self );

    foreach my $dsetName ( $self->dataSetNames ) {
	foreach my $alias ( $self->dataSetAliases($dsetName) ) {
	    $self->{_dataSetAlias}->{$alias} = $dsetName;
	}
	# Add the "real" name as an alias also:
	$self->{_dataSetAlias}->{$dsetName} = $dsetName;
    }
    return;
}

sub applyEditPolicy
{   my($self,@params) = @_;

    my(@args) = $self->{_policyObj}->applyEditPolicy( @params );

    return $args[0]||"" unless wantarray;
    return(@args);
}

sub dump {
    my($self)= @_;
    my($pack,$file,$line)=caller();
    my $text  = "DEBUG: ($PACK\:\:dump) self='$self'\n";
       $text .= "CALLER $pack at line $line ($file)\n";
    #
    # The following assumes that the current object 
    # is a simple hash ref ... modify as necessary.
    # How deep do we want to expand references here??
    #
  # foreach my $param (sort keys %$self) {
  #	$text .= " $param = $self->{$param}\n";
  # }
    foreach my $param (sort keys %{ $self->{DataSet} } ) {
	$text .= " $param = $self->{DataSet}->{$param}\n";
    }
    $text .= "_" x 25 ."\n";
    return($text);
}
#_________________________
1; # Required by require()
