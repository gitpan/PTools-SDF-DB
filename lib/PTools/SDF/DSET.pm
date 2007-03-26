# -*- Perl -*-
#
# File:  PTools/SDF/DSET.pm
# Desc:  This class implements a "simple ascii file" as a "data set."
# Date:  Thu Jun 27 09:36:05 2002
# Stat:  Prototype
#
# Abstract:
#
# Synopsis:
#

package PTools::SDF::DSET;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.07';
 @ISA     = qw( PTools::SDF::IDX );  # ISA  PTools::SDF::SDF, PTools::SDF::File

#use PTools::Local;
 use PTools::SDF::SDF qw( noparse ); # perf. enhancement #1 - no IFS parsing
 use PTools::SDF::IDX;               # include parent class
 use PTools::String;                 # string functions, including "prompt"


sub new
{   my($class,$fileName,$schema,$dataFieldRef,$idxMode,@params) = @_;

    $fileName ||= "";
    $idxMode  ||= "";

    my(@dataFields) = ($schema ? @{ $schema->{DataSet}->{Fields} } : () );

 #  if ($fileName) {
 #	$fileName = PTools::Local->path('app_datdir', $fileName)
 #	    unless $fileName =~ m#^/#;
 #  }
    # We don't need to use "mode" or "IFS" here, so leave 'undef'.
    # See the "PTools::SDF::SDF" module for further details and usage.
    # Do pass field names, even though we will reset them again, below.
    #
    my $self = $class->SUPER::new( $fileName, undef, undef, @dataFields );

    $self->setSchema( $schema );

    my(@keyFields) = ();

    if ($idxMode eq 'none') {
	# defer field indexing

    } elsif ($idxMode eq 'all') {
	push (@keyFields, $self->dataSetKeys);

    } else {
	push (@keyFields, $self->primaryKeys) if $schema;
    }
    #my(@dataFields) = $self->dataSetFields;
    #print "DEBUG: keyFields='@keyFields'\n";

    # Here we store some control information. 
    # Note that setting the 'dataFields' here overrides the default
    # behavior in the PTools::SDF::SDF class (where field names stored
    # in the "self defining file" header take presidence).

    $self->ctrl('keyFields',  join(':', @keyFields)  );
    $self->ctrl('dataFields', join(':', @dataFields) );

    # Performance enhancement #2 - replace default with faster sort
    # (sorting is left as an exercise for anyone using these files).
    # Currently, choices include
    # .  PTOols::SDF::Sort::Bubble - default, mult-keys, SLOW w/long files
    # .  PTools::SDF::Sort::Shell  - very fast, can only specify one sort key
    # .  PTools::SDF::Sort::Quick  - fastest, limited (no reverse, 1 key, ...)
    # This following step is only done in the "file wrapper" subclasses
    # that wrap files of over 100 records or so:
    #
    ## $self->extend('sort', "PTools::SDF::Sort::Shell");

    # Here we initialize any "key fields" as requested by calling module:
    #
    foreach my $keyField (@keyFields) {
	#print "DEBUG: indexInit keyField='$keyField'\n";
	$self->indexInit( $keyField ) 
    }

    return $self;
}

# Here we override methods in the parent class. We now access 
# the local snippet of the DB Schema that is particular to
# this data set.

no strict "refs";

sub schemaName     { $_[0]->{_Schema}->{SchemaName}  ||""           }
sub dataBaseName   { $_[0]->{_Schema}->{DataBase}->{BaseName}||""   }
sub dataSetNames   { sort keys %{ $_[0]->{_Schema}->{DataSet}||"" } }
sub dataBaseSchema { $_[0]->{_Schema}->{DataBase}                   }
sub dataSetSchema  { $_[0]->{_Schema}->{DataSet}                    }
sub setSchema      { $_[0]->{_Schema} = $_[1] ||""                  }

   *dsetFile    = \&dataSetFile;
   *dsetPath    = \&dataSetPath;

   *dsetTitle   = \&dataSetTitle;
   *dsetName    = \&dataSetTitle;

   *keyNames    = \&dataSetKeys;
   *dsetKeys    = \&dataSetKeys;
   *keyFields   = \&dataSetKeys;

   *fieldNames  = \&dataSetFields;
   *dsetFields  = \&dataSetFields;

   *dsetAliases = \&dataSetAliases;

# Note: The "dataSetFile" (aka "dsetFile") method just returns
#       whatever (partial) file path is defined in the "schema."
#       The "dataSetPath" (aka "dsetPath") method will return a
#       fully qualified path for the current "data set." OBTW,
#       the "ctrl" method is defined in "PTools::SDF::SDF" class.

sub dataSetTitle { $_[0]->{_Schema}->{DataSet}->{Title}   ||"" }
sub dataSetPath  { $_[0]->ctrl('fileName')                     }
sub dataSetFile  { 
    my($base,$path);
    $path = $_[0]->{_Schema}->{DataSet}->{DataFile} ||"";
    ($base,$path) = ( $path =~ m#(.*)/(.+)$# );
    return $path;
}

sub dataSetKeys
{   return( @{ $_[0]->{_Schema}->{DataSet}->{Keys} } ) if wantarray;
    return( $_[0]->{_Schema}->{DataSet}->{Keys}[0] );
}
sub dataSetFields
{   return( @{ $_[0]->{_Schema}->{DataSet}->{Fields} } ) if wantarray;
    return( $_[0]->{_Schema}->{DataSet}->{Fields}[0] );
}
sub dataSetAliases
{   return( @{ $_[0]->{_Schema}->{DataSet}->{Aliases} } ) if wantarray;
    return( $_[0]->{_Schema}->{DataSet}->{Aliases}[0] );
}
sub primaryKeys_OLD_VERSION
{   return( @{ $_[0]->{_Schema}->{DataSet}->{PriKeys} ||"" } ) if wantarray;
    return( $_[0]->{_Schema}->{DataSet}->{PriKeys}[0] ||"" );
}
sub primaryKeys       # Correct version
{   # If no "PriKeys" attribute in the "schema" return first "Keys" value
    my(@priKeys) = @{ $_[0]->{_Schema}->{DataSet}->{PriKeys} ||"" };
    @priKeys or ( @priKeys = $_[0]->{_Schema}->{DataSet}->{Keys}[0] ||"" );
    return( @priKeys ) if wantarray;
    return( $priKeys[0] ||"" );
}

sub activeKeys      { keys %{ $_[0]->{_activeKeys} }                }
sub activeKey       { defined $_[0]->{_activeKeys}->{$_[1]} ? 1 : 0 }
sub setActiveKey    { $_[0]->{_activeKeys}->{$_[1]} = $_[2] ||"1"   }
sub resetActiveKeys { $_[0]->{_activeKeys} = {}                     }

sub fieldText { $_[0]->{_Schema}->{DataSet}->{Field}->{Text}->{$_[1]||""} ||"" }
sub fieldEdit { $_[0]->{_Schema}->{DataSet}->{Field}->{Edit}->{$_[1]||""} ||"" }
sub fieldHint { $_[0]->{_Schema}->{DataSet}->{Field}->{Hint}->{$_[1]||""} ||"" }
###sub editPolicy{ $_[0]->{_Schema}->{DataSet}->{Policy}  ||"" }


   *fieldPrompt = \&getPrompt;

sub getPrompt
{   return( $_[0]->fieldText($_[1]) ) unless wantarray;
    return( $_[0]->fieldText($_[1]),
	    $_[0]->fieldEdit($_[1]),
            $_[0]->fieldHint($_[1]) );
}
sub getPrompts
{   return( $_[0]->{_Schema}->{DataSet}->{Field}->{Text} ) unless wantarray;
    return( $_[0]->{_Schema}->{DataSet}->{Field}->{Text}||{}, 
	    $_[0]->{_Schema}->{DataSet}->{Field}->{Edit}||{},
	    $_[0]->{_Schema}->{DataSet}->{Field}->{Hint}||{} ); 
}

use strict "refs";

# Allow any of the subclass modules to invoke the PTools::String->prompt()
# used to prompt user and perform rudimentary data input edits.

   *promptUser = \&prompt;

sub prompt { shift; return PTools::String->prompt( @_ ) }

sub indexInit
{   my($self,$field,%match) = @_;

    my $idx;

    if ($field =~ /&/) {
	($idx, $field) = $self->SUPER::compoundInit( $field );

    } else {
	($idx, $field) = $self->SUPER::indexInit( $field, %match );
    }
    $idx and  $self->setActiveKey( $field );
    return $idx;
}

sub compoundInit
{   my($self,@fields) = @_;

    my($idx, $field) = $self->SUPER::compoundInit( @fields );

    $idx and  $self->setActiveKey( $field );
    return $idx;
}

sub applyEditPolicy
{   my($self,$fieldName,$fieldValue,$policyRef) = @_;

    $policyRef     = $self->editPolicy;
    my(@editOrder) = $policyRef->{Order} || qw( Reject Require );

    die "Oops: 'applyEditPolicy' method moved to 'DB' class.\n";

    print "DEBUG policy:----------------------\n";
    print "DEBUG  fieldName='$fieldName'\n";
    print "DEBUG fieldValue='$fieldValue'\n";
    print "DEBUG  editOrder='@editOrder'\n";
    print "DEBUG policy:----------------------\n";

    return;
}

#_________________________
1; # Required by require()


__END__

   *fieldNames = \&dataFields;
   *keyNames   = \&keyFields;

sub dataFields
{   return( split(':', $_[0]->ctrl('dataFields') ) ) if wantarray;
    return( $_[0]->ctrl('dataFields') );
}

sub keyFields
{   return( split(':', $_[0]->ctrl('keyFields') ) ) if wantarray;
    return( $_[0]->ctrl('keyFields') );
}

sub getIndexEntry
{   my($self,$idxName,$idxValue,$fieldName) = @_;
    return $self->index($idxName,$idxValue,$fieldName);  # see PTools::SDF::IDX
}



# Fetch or Update a data field (get/set/update) via primary index
# Note: see each of the subclass modules for the proper setup
# and calling sequence for this generic 'update via index' method.

   *indexUpdate = \&idxUpd;

sub idxUpd 
{   my($self,$idxName,$idxValue,$fieldName,$newValue) = @_;

    # Due to the "parameter driven" nature of the "index" method 
    # (in PTools::SDF::IDX, inherited from the 'PTools::SDF::SDF' class), 
    # we need a special case for deleting field values.

    if ($newValue and $newValue eq "__DELETE__") {        # reset
	$self->indexDelete( $idxName, $idxValue, $fieldName );

    } else {                                # get, or set a "$newValue"
	$self->index( $idxName, $idxValue, $fieldName, $newValue );
    }
}


# Note: see each of the subclass modules for the proper setup
# and calling sequence for this generic 'updateFields' method.

   *updateFieldsViaIndex = \&updateFields;

sub updateFields
{   my($self,$idxName,$idxValue,$newValuesRef,$fieldEditsRef) = @_;

    my($fieldName,$newValue,$fieldEdit,@errorFields);

    #print "DEBUG: entering 'updateFields'\n";
    #print "DEBUG: params ($idxName,$idxValue,$newValuesRef,$fieldEditsRef)\n";

    foreach $fieldName (keys %$newValuesRef) {

	$newValue  = $newValuesRef->{$fieldName};
	$fieldEdit = $fieldEditsRef->{$fieldName};

	#print "DEBUG: fieldEdit( $fieldName, $newValue, $fieldEdit )\n";

	$self->fieldEdit( $fieldName, $newValue, $fieldEdit )
	    or push @errorFields, $fieldName;
    }

    # If ANY field edit(s) fail, do NOT update the data field(s)
    #
    if (@errorFields) {
	#print "DEBUG: edit errors occurred\n";
	my $err = "Edits failed for '". join(':', @errorFields) ."'";
	$self->setErr(-1, "$err in '$PACK'" );
    	return undef;
    }

    # If ALL field edit(s) passes, update the data field(s)
    #
    foreach my $fieldName (keys %$newValuesRef) {

	$newValue = $newValuesRef->{$fieldName};
        $newValue = "__DELETE__" unless length($newValue);

	#print "DEBUG: updating field values\n";
	$self->idxUpd( $idxName, $idxValue, $fieldName, $newValue );
    }

    return 1;
}

# Note: see each of the subclass modules for the proper setup
# and calling sequence for this generic 'fieldEdit' method.

sub fieldEdit 
{   my($self,$fieldName,$fieldValue,$fieldEdit) = @_;

    $fieldName  = "" unless defined $fieldName;
    $fieldValue = "" unless defined $fieldName;

    $self->setErr(0,"");          # assume the best

    if (! $fieldEdit ) {
	my($pack,$file,$line)=caller();
	$self->setErr(-1, "Unknown fieldName ('$fieldName') in 'fieldEdit' method of '$pack'");
	return undef;

    } elsif ( $fieldValue !~ /$fieldEdit/ ) {
	my($pack,$file,$line)=caller();
	$self->setErr(-1, "Invalid value '$fieldValue' for '$fieldName' in 'fieldEdit' method of '$pack'");
	return undef;
    }
    return 1;
}
#_________________________
1; # Required by require()
