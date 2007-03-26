# -*- Perl -*-
#
# File:  PTools/SDF/DBPolicy.pm
# Desc:  Apply edit policies to data set field values
# Date:  Thu Jun 27 09:36:05 2002
# Stat:  Prototype
#
# Note:  Simple field entry edits are usually better accomplished
#        via the "Edit" sections of the "data base schema" module.
#
# Abstract:
#        This module provides the mechanism that allows linking two
#        or more simple data files into a "data base." Using the
#        "Policy" sections of an "SDF schema", it is possible to 
#        define edits that cross file boundries. For example,
#
#        .  during "Add" or "Update" operations
#           -  ensure a key field already exists in another "data set"
#           -  ensure a key field does not exist in another "data set"
#
#        .  during "Delete" operations
#           -  this functionality is not yet implemented
#
#        The "Policy" sections may also be used to load external Perl
#        modules used to lookup default data entry values. The modules
#        must be designed to return a "hash reference" containing the
#        data using key field names that match the data entry fields.
#
#        In addition, the "Policy" sections must be used to specify
#        edits for "compound" index fields. Compound index edits may
#        not be specified via the "Edit" sections of the "schema."
#
# Synopsis:
#        This class is not intended to be used directly, but invoked
#        by calling the "applyEditPolicy" method on a "SDF Data Base."
#        This is intended for use by module designers who are building 
#        classes that will access data via an SDF "data base."
#
#           # "Schema file" (subclass of PTools::SDF::DB)
#           use PTools::SDF::MyDataBase;
#
#           $DB = new PTools::SDF::MyDataBase;
#
#
#        As each data entry field value is available, a call is made to
#        validate each particular field entry in turn.
#        
#           ($stat,$err) = $DB->applyEditPolicy(
#                                 $mode,  # one of "Add", "Update",
#                                 $dset,  # "schema" name of data set
#                                $field,  # "schema" name of data field
#                                $value,  # input value for current field
#                               $bufRef,  # (opt) hash of input data
#                                              );
#
#        When this results in a non-zero "$stat" value, "$err" will
#        contain the corresponding error message text.
#
#
#        In addition, when the "Edit Policy" is used to load an external
#        Perl module that fetches default values for the remaining data
#        entry fields, a third "hash reference" parameter is returned.
#
#           ($stat,$err, $srcRef) = $DB->applyEditPolicy( @edidtArgs );
#
#        Where "$srcRef" is expected to contain key names that correspond
#        to the field names defined for the current "data set" in the
#        "Edit" section of the "SDF schema" module for this "data base."
#
#        It is then up to the module invoking the "applyEditPolicy" to
#        determine what best use to make of the data in this hash ref.
#        Presumably it will be used to simplify data entry by presenting 
#        default values to the user for subsequent field prompts. Of
#        course these subsequent values should still be fed back through
#        the "applyEditPolicy" method to trigger edits that may be defined
#        in the "schema" module for the subsequent data set fields.
#
# Examples:
#        See the "PTools::SDF::DBUtil" module for the definitive examples 
#        of usage.
#

package PTools::SDF::DBPolicy;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.05';
#@ISA     = qw( );

 use PTools::Loader;
 use PTools::SDF::DB;


sub new
{   my($class,$DB) = @_;

    # my $self = $DB->getEditPolicy;

    bless my $self = {}, ref($class)||$class;

    # $self->set('Policy', $DB->getEditPolicy);

    $self->set('DB', $DB);

    return $self;
}

### new    { bless {}, ref($_[0])||$_[0]  }
sub set    { $_[0]->{$_[1]}=$_[2]         }   # Note that the 'param' method
sub get    { return( $_[0]->{$_[1]}||"" ) }   #    combines 'set' and 'get'
sub param  { $_[2] ? $_[0]->{$_[1]}=$_[2] : return( $_[0]->{$_[1]}||"" )    }
sub setErr { return( $_[0]->{_STATUS}=$_[1]||0, $_[0]->{_ERROR}=$_[2]||"" ) }
sub status { return( $_[0]->{_STATUS}||0, $_[0]->{_ERROR}||"" )             }
sub stat   { ( wantarray ? ($_[0]->{_ERROR}||"") : ($_[0]->{_STATUS} ||0) ) }
sub err    { return($_[0]->{_ERROR}||"")                                    }

no strict "refs";

sub setPolicy { $_[0]->{Policy} = $_[1] ||"" }

#   (@order) = $self->getOrder( $mode );

sub getOrder
{   return( "" ) unless defined $_[0]->{Policy}->{$_[1]}->{Order};
    return( @{ $_[0]->{Policy}->{$_[1]}->{Order} } ) if wantarray;
    return(    $_[0]->{Policy}->{$_[1]}->{Order}   );
}

#   $fieldRef = $self->getField( $mode, $type, $fieldName );
#
#             Where    mode = {     Add | Update }
#                      type = { Require | Reject }
#                 fieldName = < name of field to edit >

sub getField  { return( $_[0]->{Policy}->{$_[1]}->{$_[2]}->{$_[3]} ||"" ) }

sub getEdits  { @{ $_[0]->{Policy}->{$_[1]}->{$_[2]}->{$_[3]}->{Edit}  ||"" } }
sub getHints  { @{ $_[0]->{Policy}->{$_[1]}->{$_[2]}->{$_[3]}->{Hint}  ||"" } }
sub getSource { @{ $_[0]->{Policy}->{$_[1]}->{$_[2]}->{$_[3]}->{Source}||"" } }
sub getLogic  {    $_[0]->{Policy}->{$_[1]}->{$_[2]}->{$_[3]}->{Logic} ||""   }

use strict "refs";


sub applyEditPolicy
{   my($self,$mode,$dsetName,$fieldName,$value,$bufferRef,$policyRef) = @_;
    #
    #      $mode - one of "Add", "Update", ... this corresponds to the "type"
    #              of policy edit to apply as defined in the "schema" module
    #  $dsetName - name of the data file containing the field we're editing
    # $fieldName - name of the data field that we are (potentially) editing
    #     $value - value for the data field entered by user (or batch file)
    # $bufferRef - (opt) hash ref containing all input prior to current field
    # $policyRef - (opt) usually not passed here (see "getEditPolicy" call)
    #
    $mode = ucfirst( lc($mode) );

    my $DB       = $self->get('DB');
    $policyRef ||= $DB->getEditPolicy( $dsetName );  # get policy from schema

  # print "DEBUG: mode='$mode'  policy='$policyRef'\n";

    $policyRef or return( 0,"" );        # no policy edit for this field

    #-------------------------------------------------------------------
    # Okay, we have a policy definition ... does it apply to current field?
    #
    $self->setPolicy( $policyRef );    # simplify access to components

    my(@editOrder) = $self->getOrder( $mode );
    (@editOrder) or (@editOrder) = qw( Require Reject );

    my($fieldRef, $srcRef) = ("","");

    foreach my $type (@editOrder) {       # e.g., "Add", "Update", ...

	$fieldRef = $self->getField( $mode, $type, $fieldName );

	next unless $fieldRef;            # nope, doesn't apply

	#---------------------------------------------------------------
	# Okay ... we have a policy definition ... FOR THIS field.
	#
	# Note that "$fieldName" is the current field that triggered
	# this policy edit ... this is NOT necessarially the same as
	# the field edit that will actually occur here. I.e., the
	# edit we will apply can consist of any field value entered
	# up to and including the current "$fieldName" entry.
	#
	# For this to work, an optional "field/value" buffer (passed
	# as a hash reference) is expected to be available here.
	# Hope this is clear ... see notes, above, regarding the
	# arguments passed into this method.
	#
	# "$mode" is one of "Add",     "Update"
	# "$type" is one of "Require", "Reject"
	#
	# print "DEBUG: fieldRef='$fieldRef'\n";

	my(@edit) = $self->getEdits( $mode, $type, $fieldName );
	my(@hint) = $self->getHints( $mode, $type, $fieldName );
	my(@src)  = $self->getSource($mode, $type, $fieldName );
	my($logic)= $self->getLogic ($mode, $type, $fieldName );

	unless ( $logic ) {
	    $logic = "OR"  if $type eq "Reject";
	    $logic = "AND" if $type eq "Require";
	}
	$logic = uc $logic;

	0 and print "DEBUG:    Source='@src'\n";
	0 and print "DEBUG       mode='$mode'\n";

	if (@src) {
	    my $hint = $hint[0] ||"";

	    $srcRef = $self->fetchSource($fieldName, $type, $value, @src);

	    my $stat = (ref $srcRef ? 0 : -1);

	    0 and print "DEBUG $mode $type $fieldName: srcRef='$srcRef'\n";

	    next;
	    ##return( $stat,$hint,$ref);
	}
	#
	# When multiple edits are defined, process as follows:
	# Case:
	#   1)  Reject mode:   OR logic - ANY failure  and edit fails   (DFLT)
	#   2)                AND logic - ALL failures  or edit passes
	#
	#   3) Require mode:   OR logic - ANY successes and edit passes
	#   4)                AND logic - ALL successes  or edit fails  (DFLT)
	#
	my($editFailed,$editPassed) = (0,0);
	my($orLogic,$andLogic)      = (0,0);
	my $editResult              = 0;
	my $hint;

	foreach my $idx (0 .. $#edit) {
	    # print "DEBUG $mode $type $fieldName: edit='$edit[$idx]'\n";
	    # print "DEBUG logic='$logic'  edit value='$value'\n";
	    # print "DEBUG $mode $type $fieldName: hint='$hint[$idx]'\n";
	    # print "DEBUG ---------------------------\n";

	    if ( $self->applyFieldEdit($fieldName, $type, $value, $edit[$idx], $bufferRef) ) {
		$editPassed = 1;

		if ($type eq "Reject" and $logic eq "AND") {
		    #
		    # Case 2: PASS! Short circut edits early, since we can ...
		    #
		    0 and print "DEBUG: Case 2: early PASS\n";
		    return( 0,"",$srcRef );

		} elsif ($type eq "Require" and $logic eq "OR") {
		    #
		    # Case 3: PASS! Short circut edits early, since we can ...
		    #
		    0 and print "DEBUG: Case 3: early PASS\n";
		    return( 0,"",$srcRef );

		} else {
		    next;
		}
	    }
	    $editFailed = 1;

	    # Collect hint value for the first edit error only.
	    #
	    $hint ||= $hint[$idx];

	    if (! $hint) {
		($type eq "Reject") and $hint = 
		    "duplicate entry for '$fieldName' in '$dsetName' file";

		($type eq "Require") and $hint = 
		    "entry not found for '$fieldName' in '$dsetName' file";
	    } 
	    # print "OOPS: EDIT Failed; return '$hint'\n";

	# Case:
	#   1)  Reject mode:   OR logic - ANY failure  and edit fails   (DFLT)
	#
	#   4) Require mode:  AND logic - ALL successes  or edit fails  (DFLT)
	#

	    if ($type eq "Reject" and $logic eq "OR") {
		#
		# Case 1: FAIL! Short circut edits early, since we can ...
		#
		0 and print "DEBUG: Case 1: early FAIL\n";
		return(-1, $hint, "");              # DFLT "Reject" logic

	    } elsif ($type eq "Require" and $logic eq "AND") {
		#
		# Case 4: FAIL! Short circut edits early, since we can ...
		#
		0 and print "DEBUG: Case 4: early FAIL\n";
		return(-1, $hint, "");              # DFLT "Require" logic
	    }

	}   # END foreach my $idx (0 .. $#edit) {

	# Case 1: PASS!
	if ($type eq "Reject" and $logic eq "OR") {     # DFLT "Require" logic
	    0 and print "DEBUG: Case 1: late PASS\n";
	    return(-1, $hint, "") if $editFailed;       # just to be careful!
	    ### return( 0,"",$srcRef );                 # but DON'T return yet
	}

	# Case 2: FAIL!
	if ($type eq "Reject" and $logic eq "AND") {
	    0 and print "DEBUG: Case 2: late FAIL\n";
	    return(-1, $hint, "") unless $editPassed;   # just to be careful!
	}

	# Case 3: FAIL!
	if ($type eq "Require" and $logic eq "OR") {
	    0 and print "DEBUG: Case 3: late FAIL\n";
	    return(-1, $hint, "") unless $editPassed;   # just to be careful!
	}

	# Case 4: PASS!
	if ($type eq "Require" and $logic eq "AND") {   # DFLT "Reject" logic
	    0 and print "DEBUG: Case 4: late PASS\n";
	    return(-1, $hint, "") if $editFailed;       # just to be careful!
	    ### return( 0,"",$srcRef );                 # but DON'T return yet
	}

	if (0) {
	    print "DEBUG applyEditPolicy: ------------\n";
	    print "DEBUG       mode='$mode'\n";
	    print "DEBUG       type='$type'\n";
	    print "DEBUG      logic='$logic'\n";
	    print "DEBUG   dsetName='$dsetName'\n";
	    print "DEBUG  fieldName='$fieldName'\n";
	    print "DEBUG fieldValue='$value'\n";
	    print "DEBUG  editOrder='@editOrder'\n";
	    print "DEBUG  policyRef='$policyRef'\n";
	    print "DEBUG applyEditPolicy--------------\n";
	    #die $self->dump;
	}

    }   # END foreach my $type (@editOrder) {       # e.g., "Add", "Update", 

  # print "DEBUG: returning srcRef='$srcRef'\n";

    return( 0,"",$srcRef );
}

sub applyFieldEdit
{   my($self,$fieldName,$type,$value,$edit,$bufferRef) = @_;

  # return 1 if $edit eq "skip";

    my $DB = $self->get('DB');
    my($dsetName,$dsetField) = split(':', $edit);

    my $dsetObj = $DB->dataSet( $dsetName );

    #--------------------------------------------------------
    # Before we actually apply the field edit, figure out
    # what edit this current edit policy actually expects.

    my($editField,$editValue) = ("","");
    my(@editFields)           = split("&",$dsetField);

    # When editing a "compound" field, build a compound key;
    # when editing a "simple" field, just build a simple key.
    #
    foreach my $field (@editFields) {
	$editField .= "$field\&";
	if ($field eq $fieldName) {       # if this is current field
	    $editValue .= "$value\&";     # ... then use current value
	} else {
	    $editValue .= "$bufferRef->{$field}\&";
	}
    }
    chop $editField;                      # remove trailing ampersand
    chop $editValue;                      # remove trailing ampersand

    $editValue ||= $value;                # VERIFY THIS FIX.

    if (0) {
	print "DEBUG applyFieldEdit: ------------- ($PACK)\n";
	print "DEBUG         type='$type'\n";
	print "DEBUG    fieldName='$fieldName'\n";
	print "DEBUG        value='$value'\n";
	print "DEBUG         edit='$edit'\n";
	print "DEBUG     dsetName='$dsetName'\n";
	print "DEBUG    dsetField='$dsetField'\n";
	print "DEBUG      dsetObj='$dsetObj'\n";
	print "DEBUG   editFields='@editFields'\n";
	print "DEBUG    editField='$editField'\n";
	print "DEBUG    editValue='$editValue'\n";
	print "DEBUG applyFieldEdit--------------- (bufferRef)\n";
	foreach my $key (sort keys %$bufferRef) {
	    print "DEBUG     $key = $bufferRef->{$key}\n";
	}
	print "DEBUG applyFieldEdit---------------\n";
    }
    #--------------------------------------------------------
    # If key not initialized in the data set, do so now; the
    # "indexInit" works for "simple" and "compound" indices.

    $dsetObj->indexInit( $editField ) unless $dsetObj->activeKey( $editField );

    #--------------------------------------------------------
    # Return a "true" value to indicate a successful edit
    #
    # Note that this only works with data set "key" fields now;
    # however, this works for both simple and "compound" keys.

##  # my(@idx) = ($editField, $editValue);
##  # my $dsetValue = $dsetObj->index( @idx, $editField );
##
##    my $recNum 
##
## if (1) {
##    print "DEBUG validate:--------------------\n";
##    print "DEBUG  editValue='$editValue'\n";
##    print "DEBUG  dsetValue='$dsetValue'\n";
##    print "DEBUG validate:--------------------\n";
## }
##
##    return 1 if $dsetValue eq $value;              # no change to data

    if ($dsetObj->index($editField, $editValue) ) {  # Found
	return 1 if $type eq "Require";                # Ok, successful
	return 0 if $type eq "Reject";                 # Oops, failed
    } else {                                         # Not found
	return 0 if $type eq "Require";                # Oops, failed
	return 1 if $type eq "Reject";                 # Ok, successful
    }
    return 1;                                        # Okay, successful
}

sub fetchSource
{   my($self, $fieldName, $type, $value, @src) = @_;

    my $class  = shift @src;
    my $method = shift @src;
    my (@args) = @src;

    unshift(@args, $value);

    PTools::Loader->use( $class );

  # print "DEBUG: SOURCE: \$srcRef = $class->$method( @args )\n";

    return undef unless $class and $method;

    my $srcRef = $class->$method( @args );

  # if (ref $srcRef) {
  #    foreach my $key (sort keys %$srcRef) {
  #	  print " DEBUG: src $key => $srcRef->{$key}\n";
  #    }
  # }
  # print "DEBUG: srcRef='$srcRef' in '$PACK'\n";

    return $srcRef;
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
    foreach my $param (sort keys %$self) {
   	$text .= " $param = $self->{$param}\n";
    }
    $text .= "_" x 25 ."\n";
    return($text);
}
#_________________________
1; # Required by require()
