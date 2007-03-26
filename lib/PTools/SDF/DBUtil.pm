#!/usr/local/bin/perl -w
#
# File:  PTools/SDF/DBUtil.pm
# Desc:  Query/Update/Add/Load utility for "simple data base system" (SDF DB)
# Auth:  Chris Cobb, Hewlett-Packard Co., Cupertino, CA <cobb@cup.hp.com>
# Date:  Thu Jul 18 18:03:09 2002
#
# Usage:
#        ...bin/dbutil.pl -h
#
# Abstract:
#        This module is a proof-of-concept to demonstrate various access
#        methods using the following SDF Data Base abstraction classes:
#
#        PTools::SDF::DB     PTools::SDF::DSET    PTools::SDF::DBPolicy 
#
#        and the "Schema" format as implemented in a "data base" definition 
#        class. See the class PTools::SDF::DemoDB for examples of the schema 
#        format.
#
#        Notice that no data base, data set or data field information is
#        hard-coded in this module. All prompts, field edits, data entry
#        "hints" and default values are obtained using SDF DB/DSET calls.
#
# Note:  The "PTOols::SDF::DBUtil::Options" class is included in this file.
#
# WARN:  Now that key fields may be updated, add a fix to INVALIDATE the
#        ENTIRE key in the data set (when a key field is modified). This
#        way the key will be re-indexed during next use. See below.
#
# Dependencies:
#        This module relies on several of the PerlTools global library
#        modules. See "http://www.ccobb.net/ptools/" for an overview.
#

package PTOols::SDF::DBUtil;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.14';
#@ISA     = qw( );

 use PTools::Global;                    # PerlTools global vars, methods
 use PTools::SDF::DB;                   # simple data file dbm (SDF DB)
#use PTools::SDF::DBUtil::Options;      # package included in this file
 use PTools::Loader qw( generror );     # load Perl modules, abort on err
 use PTools::String;                    # miscellaneous string functions
 use PTools::WordWrap;                  # wrap text to arbitrary margin


sub new    { bless {}, ref($_[0])||$_[0] }
sub set    { $_[0]->{$_[1]}=$_[2]         }   # note that the 'param' method
sub get    { return( $_[0]->{$_[1]}||"" ) }   # combines both 'set' and 'get'
sub param  { $_[2] ? $_[0]->{$_[1]}=$_[2] : return( $_[0]->{$_[1]}||""   )  }
sub setErr { return( $_[0]->{_STATUS}=$_[1]||0, $_[0]->{_ERROR}=$_[2]||"" ) }
sub status { return( $_[0]->{_STATUS}||0, $_[0]->{_ERROR}||"" )             }
sub stat   { ( wantarray ? ($_[0]->{_ERROR}||"") : ($_[0]->{_STATUS} ||0) ) }
sub err    { return($_[0]->{_ERROR}||"")                                    }

sub Base   { return( $_[0]->{Base}->new ) }     # "Base" is "singleton" class


sub run
{   my($self,$initParamRef,@runParams) = @_;

    ref $self or $self = new $PACK;

    my($DB, $method) = $self->init( $initParamRef );

    if ($DB) {
	##die $DB->dump;
	#die Global->dump('incpath');  # DEBUG: print current "lib" path(s)
	#print Global->dump('inclibs');  # DEBUG: print current module list

	$method  ||= "query";           # method = "add", "update" or "query"
        my $dbName = $DB->dbaseName;
	my $dbLock = $DB->isLocked;
	my $dbType = $DB->serverType;   # (local or remote data files)

	print $self->helpText( $dbName, $dbLock, $dbType );

	$method and $self->$method( @runParams );

	print "-" x 72 ."\n";
    }
    my($stat,$err) = $self->status;

    if ($DB and $DB->isLocked) {
	my $dbName = $DB->dbaseName;
	print "Unlocking $dbName ... ";
	$DB->unlock;                           # attempt to unlock "data base"
	if ($DB->notLocked) { print "ok\n" } else { die "NOT\n" }
    }
    print "\n";

    my $dsetUpdate = $self->get('DsetUpdate') ||"";
    if (ref $dsetUpdate and keys %$dsetUpdate) {
	print "The following data set(s) were updated this session:\n";
	foreach my $dsetName (sort keys %$dsetUpdate) {
	    print "  $dsetName\n";
	}
	print "\n";
    }

    return( $stat ? 1 : 0 );
}

sub init 
{   my($self,$paramRef) = @_;

    $| = 1;  # unbuffer STDOUT

    ref $self or die "Ouch: 'init' called as a 'class method'";

    my $optsObj = "PTools::SDF::DBUtil::Options"->new( $paramRef );

    $self->set('OptsObj',    $optsObj);
    $self->set('DsetUpdate', {});            # track list of DSET changes

    my($stat,$err) = $optsObj->status;
    if ($stat) {
	print "$err\n";
	$self->setErr($stat,$err);
	return;
    }

    my $mode = $optsObj->mode;

    # print "DEBUG: mode='$mode' in '$PACK'\n";
    #-------------------------------------------------------------------
    # Note: when adding $mode options, be sure to set "lockFlag", too.

    my $Base = $self->{OptsObj}->dataBase || die "No Data Base specified";

    ## Now loaded in Options module:
    ## Loader->use( $Base );        # attempt to load Schema, abort on error

    $self->set('Base', $Base);      # cache base name for later use

    my $DB = $self->Base;           # "open" the data base

    ($stat,$err) = $DB->status;
    die "\n Client error: unable to connect to AccountsDB\n ($err)\n\n"
	if $stat;

    unless ($optsObj->queryMode) {
	#
        # Lock DB when running in { add | update | load } mode
	#
	my $dbName = $DB->dbaseName;
	print "Locking $dbName ... ";

	$DB->advisoryLock;          # attempt to lock the "data base"

	if ($DB->isLocked) { 
	    print "ok\n";
	} else {
	    print "NOT\n"; 
	    print "\n Unable to lock data base for updates. Try again later.\n";

	    $self->setErr(-1,"Unable to lock data base for updates");

	    if (0) {     ### ($optsObj->verbose) {
	       my($stat,$err) = $DB->status;
	       my $lockFile   = $DB->dataBaseLock;
	       print " Error: $err\n";
	       print " ($lockFile)\n";
	    }
	    return;
	}
    }

    return( $DB, $mode);
}   

sub helpText
{   my($self, $dbName,$lockFlag,$type) = @_;

    my $mode = ($lockFlag ? "read/write" : "read only");
    $type  ||= "(unknown)";

    return( "-" x 72 ."\n"
          . "Simple Data File DB Utility \t\t\t\tMode: $mode\n"
          . "\t\t\t\t\t\t\tType: $type\n"
          . "Access ascii file 'data sets' using key field(s).\n"
          . "The following special characters are recognized:\n\n"
          . "   ?   - display data entry hint for a field\n"
          . "   /   - cancel input and start over\n"
          . "   //  - terminate data entry and exit\n"
          . "\n"
          . "Currently accessing:  $dbName\n"
          . "\n" );
}

sub add
{   my($self,$dsetName) = @_;

    my $DB     = $self->Base;

  # my $dbName = $DB->dbaseName;
  # my $dbLock = $DB->isLocked;
  # my $dbType = $DB->serverType;   # (local or remote)
  #
  # print $self->helpText( $dbName, $dbLock, $dbType );
  #
    my(@dataSetList) = $DB->fullAliasList;
    my $input        = "";
    my $interactive  = "";

    while ($input ne "//") {
	print "-" x 72 ."\n\n";

	if (! $dsetName) {
	    #------------------------------------------------------------
	    # PROMPT user for a data set name
	    #
	    $input  = $self->promptForDataSet( $DB, "Add" );
	    if ($input =~ m#^(/|//)$#) { print "\n"; next; }

	    $dsetName = $input;
	    $interactive  = "1";
	}
	grep(/^$dsetName$/, $DB->fullAliasList)
	    || print "\n * * Oops: unknown data set '$dsetName'\n\n";

	my $dsetObj  = $DB->dset( $dsetName );
	my $recNum   = $dsetObj->param;
	$recNum++;

	$input = $self->updateRecord( $dsetName, $recNum );
	$dsetName = "" if $interactive;
    }
    return;
}

sub load
{   my($self) = @_;

    my $mode      = $self->get('OptsObj')->mode;
    my $dsetName  = $self->get('OptsObj')->dataSet;
    my $fileObj   = $self->get('OptsObj')->fileObj;
    my $DB        = $self->Base;

    # Check to see if we were given a data set "alias"

    $dsetName = $DB->dataSetName( $dsetName );   # 

    my(@dataSetAliases) = $DB->fullAliasList;

    print "-" x 72 ."\n";

    if (! grep(/^$dsetName$/, @dataSetAliases) ) {
	##my $err = "Invalid data set name '$dsetName'";
	my $err = "unknown data set '$dsetName'";
	print "\n * * Oops: $err\n\n";
	$self->setErr(-1,$err);
	return;
    }

    my $dsetObj    = $DB->dset( $dsetName );
    my $dsetTitle  = $dsetObj->dsetName;
    my $recNum     = $dsetObj->param;          # 0-based record count
    my $primKey    = $dsetObj->primaryKeys;

    $dsetObj->setErr(0,"");

  # die $dsetObj->dump(0,1);
  # die "primKey='$primKey'\n";

    my($newDataRef,$status) = ("",0);

    #_________________________________________________________
    # Okay ... here we go.

    my $loadCount = 0;
    my $recCount  = $fileObj->count;
    my $entries   = String->plural( $recCount, "entr","ies","y" );
    print "Attempt to ". ucfirst($mode) ." $recCount $dsetTitle $entries\n\n";

    foreach my $idx ( 0 .. $fileObj->param ) {

	$recNum++ unless $status;
	print "  ". "-" x 45 ."\n";
	print "  Adding file record $idx to data set record $recNum\n\n";

	$newDataRef = $fileObj->getRecEntry( $idx );

	$status = $self->loadRecord( $dsetName, $recNum, $newDataRef );

	if ($status) {
	    print "\n  Error: failed to load file record $idx ($primKey:$newDataRef->{$primKey})\n\n";
	} else {
	    print "\n  Okay: successfully loaded file record $idx\n\n";
	    $loadCount++;
	}
    }
    #_________________________________________________________
    # That' all, folks!

    print "-" x 72 ."\n";
    print "\nSuccessfully loaded $loadCount of $recCount $entries\n";

    if ($loadCount) {
	print "Saving updated data file\n";
	$dsetObj->save;                     # save the new additions

	my($stat,$err) = $dsetObj->status;
	$stat and die "\n * * Ouch: $err\nabort ";
    }
    print "\n";

  # my $dsetObj = $DB->dset( $dsetName );
  # print "load $dsetName\n";
  # print $fileObj->dump;
  # print $dsetObj->dump;

    return;
}


# Update mode will query then allow updates

   *update = \&query;

sub query
{   my($self) = @_;
    #
    # Query the data base interactivelly
    #
    my $DB     = $self->Base;

  # my $dbName = $DB->dbaseName;
  # my $dbLock = $DB->isLocked;
  # my $dbType = $DB->serverType;   # (local or remote)
  #
  # print $self->helpText( $dbName, $dbLock, $dbType );
  #
    my($input,$dsetName,$keyField,$value) = ("","","","");

    my $dsetObj     = "";
    my(@keyFields)  = ();

    while ($input ne "//") {

        print "-" x 72 ."\n\n";
	#------------------------------------------------------------
	# PROMPT user for a data set name
	#
	$input = $self->promptForDataSet( $DB );

	if ($input =~ m#^(/|//)$#) { print "\n"; next; }

	$dsetName= $input;

        $dsetObj = $DB->dset( $dsetName );

        (@keyFields) = $dsetObj->dsetKeys;     # FIX: dup of 'keyFields' method

	if ($#keyFields < 0) {

	    print "\n * * Ouch: No key fields found for '$dsetName' file\n\n";
	    next;

	} elsif ($#keyFields > 0) {

	    #--------------------------------------------------------
	    # PROMPT user for a key field name, IFF multiple keys exist
	    #
	    $input = $self->promptForDataField( $dsetObj, \@keyFields);

	    if ($input =~ m#^(/|//)$#) { print "\n"; next; }

	    $keyField = $input;

	} else {
	    $keyField = $dsetObj->keyFields;
	}

	#--------------------------------------------------------
	# If key not initialized in the data set, do so now.
	#
	if (! $dsetObj->activeKey( $keyField ) ) {
	   $dsetObj->indexInit( $keyField );
	}

	#--------------------------------------------------------
	# PROMPT user for a field value
	#
	$input = $self->promptForDataValue( $dsetObj, $keyField );

	if ($input =~ m#^(/|//)$#) { print "\n"; next; }

	$value = $input;

	my $recNum = $self->formatResult( $dsetName, $keyField, $value );

	$recNum = "" unless defined $recNum;
	
	if (length($recNum) and $DB->isLocked) {

	    my($text,$edit,$hint);

	    $text = "Update record ". ($recNum + 1) ." [n]";
	    $text = String->justifyRight( "${text}: ", 30 );
	    $edit = '^([Yy][Ee]?[Ss]?|[Nn][Oo]?)$';  ### $edit = '^([YyNn])$';

	    $hint = "\n * * Enter a 'y' for yes, or a 'n' for no (D'Oh!)\n\n";
	    #------------------------------------------------------------
	    # PROMPT user for a yes or no answer
	    #
	    $input = $self->promptLoop($text,$edit,$hint,"n");

	    if ($input =~ m#^(/|//)$#) { print "\n"; next; }

	    $input = $self->updateRecord( $dsetName, $recNum, $keyField )
		if ($input =~ /^([Yy])/);

	    print "\n";
	}

    } # end of   while ($input ne "//") {

    return;
}

sub promptForDataSet
{   my( $self, $DB, $mode) = @_;

    my $default = $self->{Defaults}->{__DefaultDset__} ||"";

    my(@dataSetList)    = $DB->dataSetList;
    my(@primSetList)    = $DB->primarySetList;
    my(@dataSetAliases) = $DB->fullAliasList;

    (@dataSetList) or die $DB->dump;

    # print "DEBUG:   dataSetList='@dataSetList'\n";
    # print "DEBUG: fullAliasList='@dataSetAliases'\n";

    $default ||= $primSetList[0];
    $default ||= $dataSetList[0];

    my $text = " Data set [$default]: ";
    my $edit = "^(|". join('|', @dataSetList, @dataSetAliases) .")\$";
    my $hint = "\n * * Enter one of '". 
    	  join("', '", @dataSetList) ."' or <null>\n\n";

    $text = String->justifyRight( $text, 30 );
    $hint = WordWrap->parse( 72, $hint );

    my $dset = $self->promptLoop($text,$edit,$hint,$default);

    if ($dset !~ m#^(/|//)$#) {
	$dset = $DB->dsetName( $dset );
	#print "DEBUG: setting __DefaultDset ='$dset'\n";
	$self->{Defaults}->{__DefaultDset__} = $dset;
    }

    return $dset;
}

sub promptForDataField
{   my($self, $dsetObj, $keyFieldRef) = @_;

    my $dsetName = $dsetObj->dsetName;
    my $default  = $self->{Defaults}->{"_Key_$dsetName"} ||"";
    $default   ||= $dsetObj->primaryKeys;
    $default   ||= $dsetObj->keyFields;

    my $text = " Key field [$default]: ";
    my $edit = "^(|". join('|', @$keyFieldRef) .")\$";
    my $hint = "\n * * Enter one of '". 
	join("', '", @$keyFieldRef) ."' or <null>\n\n";

    $text = String->justifyRight( $text, 30 );
    $hint = WordWrap->parse( 72, $hint );

    my $keyField = $self->promptLoop($text,$edit,$hint,$default);

    if ($keyField !~ m#^(/|//)$#) {
	#print "DEBUG: setting '_Key_$dsetName'='$keyField'\n";
	$self->{Defaults}->{"_Key_$dsetName"} = $keyField;
    }

    return $keyField;
}

sub promptForDataValue
{   my($self, $dsetObj, $keyField) = @_;

    my ($text,$edit,$hint) = $dsetObj->fieldPrompt( $keyField );

    $text ||= "'$keyField'";

    my $default = $self->{Defaults}->{$keyField} ||"";

    my $defaultText = ($default ? " \[$self->{Defaults}->{$keyField}\]" : "");

    $text = String->justifyRight( "${text}${defaultText}: ", 30 );

    $hint = "\n * * Enter $hint\n\n" if $hint;

    my $value = $self->promptLoop($text,$edit,$hint,$default);

    if ($value and $value !~ m#^(/|//)$#) {
	if ( length($dsetObj->recNumber( $keyField, $value )) ) {
	    #print "DEBUG: setting __$keyField ='$value'\n";
	    $self->{Defaults}->{$keyField} = $value;
	}
    }

    return $value;
}

sub promptLoop
{   my($self,$text,$edit,$hint,$default) = @_;

    $hint ||= "\n * * (No hint available for this field)\n\n";
    my $input = '?';
    while ($input eq '?') {
	#
	# PROMPT user for input;  display data entry hint if '?' entered.
	# Note that when an "$edit" value is passed and a single '?' char
	# is not valid input, the "promptUser" method prints the hint.
	#
	$input = String->promptUser($text,$edit,$hint,$default);

	print $hint if ($input eq "?");
    }
    return $input;
}

sub updateRecord
{   my($self, $dsetName,$recNum,$keyField) = @_;

    unless ( defined $recNum and length($recNum) ) {
	print "\n * * Ouch: missing 'recNum' parameter in 'updateRecord'\n";
	print "\n";
	return;
    }

    $keyField ||= "";

    my $DB      = $self->Base;
    my $dsetObj = $DB->dataSet( $dsetName );
 ## my $dsetName= $dsetObj->dsetName;
    my $hashRef = $dsetObj->recEntry( $recNum );
    my $srcRef  = "";                            # allow for hashRef Overrides

    my $mode    = $self->{OptsObj}->get("Mode");

  # print "DEBUG: MODE='$mode'\n";
 ## print "Update entry at record number ". ($recNum + 1) ."\n\n";

    my(@dataFields) = $dsetObj->ctrl('dataFields');    # FIX: add a method
    my(@keyFields)  = $dsetObj->dsetKeys;     # FIX: dup of 'keyFields' method

    my($text,$edit,$hint,$value);
    my($input,$stat,$err);
    my $recordUpdate = 0;

    print "\n\t--------------------------------\n";
    print "\t". ucfirst($mode) ." $dsetName entry\n\n";

    foreach my $field (@dataFields) {

	#print "DEBUG(1): field='$field'\n";

	#next if $field eq $keyField;      # prevent update of current key
	if ($mode =~ /^[Uu]pdate/) {
	    next if grep(/^$field$/, @keyFields);
	}

	($text,$edit,$hint) = $dsetObj->fieldPrompt( $field );

	next if $edit eq "skip";
	if ($edit eq "time") {
	    $hashRef->{$field} = time;
	    next;
	}
	# print "  prompt for field='$field'\n";   #DEBUG:

	#__________
	# FIX: which takes prescidence here??
	#
	if (ref $srcRef) {
	    $value = $srcRef->{$field}  ||""; 

	} elsif ($mode =~ /[Uu]pdate/) {
	    $value = $hashRef->{$field} ||"";
	} else {
	    $value = "";
	}
	#__________

	$text ||= $field;
	$hint &&= "\n * * Enter $hint\n\n";

	($value) and $text = String->justifyRight( "${text} [$value]: ", 40 );
	($value)  or $text = String->justifyRight( "${text}: ", 40 );

	my $tmpRef;

	# Note: the "hashRef" used to collect up the user's input
	# is now passed through to the "applyEditPolicy" method.
	# This allows for more complex policy edits then before.
	#
	($input,$tmpRef) = $self->promptForUpdateValue(
		$dsetName,$field,$text,$edit,$hint,$value,$hashRef );


	$tmpRef and $srcRef = $tmpRef;
	##ref $srcRef and print "DEBUG: srcRef='$srcRef' in 'BAR'\n";

	if ($input =~ m#^(/|//)$#) {
	    # If this data is flagged as having a record change
	    # (but not yet saved to disk), RESET the flag here
	    # as no change to this record will be saved.
	    #
	    $recordUpdate = 0;

	    return $input;
	}

	# WARNING:
	# FIX: when updating a key field, INVALIDATE that key
	#      in the data set. This way, the next access to
	#      that key field will rebuild the index.

	if ( length($input) ) {
	    $hashRef->{$field} = $input;
	    #print "DEBUG: setting __$field ='$input'\n";
	    $self->{Defaults}->{$field} = $input;
	}
	#
	# If input not equal the current value, flag this data set as
	# having a record change (but not yet saved to disk).
	# Note that this should NOT set the flag, even if the record
	# was actually updated, when none of the data values changed.
	#
	if ($input ne $value) {
	    $recordUpdate = 1;
	}

    }  # end   foreach my $key (@dataFields) {

    # DEBUG XYZ:
    #print "\n  DEBUG: RESULTS ...\n\n";
    #foreach my $key (sort keys %$hashRef) 
    #	{ printf( "%15s: %-40s\n", $key, $hashRef->{$key} ) }

    if ($recordUpdate or $mode =~ /^[Aa]dd/) {
	# Only save the changes if this record was flagged as having
	# a field change during "update", or we are in "add" mode.
	#
	$dsetObj->param($recNum, $hashRef);       # add/update record number

	($stat,$err) = $dsetObj->status;
	$stat and die "\n * * Ouch: $err\nabort "
	    unless $err =~ m#No records found in#;

	$dsetObj->save;                           # save the entry

	($stat,$err) = $dsetObj->status;

	if ($stat) {
	    print "\n * * Oops: $err\n\n";
	} else {
	    print "\n -- Okay, $mode successful for ". ($recNum + 1) ." --\n\n";
	}
	# After a succssful "save to disk," set a flag here so we
	# can remind the user just which file(s) were updated
	# upon exiting this module.
	#
	my $dsetUpdate = $self->get('DsetUpdate')
	    || die "No 'DsetUpdate' hash found to update";
	$dsetUpdate->{$dsetName} = 1;

    } elsif ($mode =~ /^[Uu]pdate/) {
	print "\n -- $mode unnecessary as no change made to record --\n\n";
    }

    ##my(@keyFields) = $dsetObj->dsetKeys;     # FIX: dup of 'keyFields' method

    return $hashRef unless $mode =~ /^[Aa]dd/;

    # FIX: are we allowing updates to key fields? IF SO, reinit keys here!!
    # reinitialize data set key(s) for ADDs
    # Currently: Key field is not included in prompts for update value.
    #
    foreach my $keyField (@keyFields) { $dsetObj->indexInit( $keyField ) }

    return $hashRef;
}

sub loadRecord
{   my($self, $dsetName,$recNum,$newDataRef) = @_;

    if ( (! defined $recNum) or (! length($recNum)) ) {
	print "\n * * Ouch: missing 'recNum' parameter in 'loadRecord'\n";
	return;
    } elsif ( ! ref($newDataRef) ) {
	print "\n * * Ouch: missing 'dataRef' parameter in 'loadRecord'\n";
	return;
    }

    my $DB       = $self->Base;
    my $dsetObj  = $DB->dataSet( $dsetName );
    my $hashRef  = $dsetObj->recEntry( $recNum );
    my $srcRef   = "";                           # allow for hashRef Overrides

    my $mode    = $self->{OptsObj}->get("Mode");

  # print "DEBUG: MODE='$mode'\n";
 ## print "Load entry at record number ". ($recNum + 1) ."\n\n";

    my(@dataFields) = $dsetObj->ctrl('dataFields');    # FIX: add a method
    my(@keyFields)  = $dsetObj->dsetKeys;     # FIX: dup of 'keyFields' method

    my($text,$edit,$hint,$value);
    my($input,$stat,$err);
    my $tmpRef;
    my $result = 0;

    $self->setErr(0,"");                       # assume the best

    foreach my $field (@dataFields) {

	if (ref $srcRef) {
	    $value = $srcRef->{$field}  ||""; 
	    $value ||= ( $newDataRef->{$field} ||"" );
	} else {
	    $value = $newDataRef->{$field} ||"";
	}

	($text,$edit,$hint) = $dsetObj->fieldPrompt( $field );

	$text ||= $field;
	$text  = String->justifyRight( "${text}: ", 20 );

	print $text . $value ."\n";

	#print "DEBUG(1): field='$field'\n";
	#print "DEBUG(1): value='$value'\n";
	#print "DEBUG(1):  edit='$edit'\n";

	#($edit eq "time") and $value = time;
 
	# Note: the "newDataRef" used to collect up the user's input
	# is now passed through to the "applyEditPolicy" method.
	# This allows for more complex policy edits then before.
	#
	($input,$tmpRef) = $self->editLoadValue(
		$dsetName,$field,$text,$edit,$hint,$value,$newDataRef );

	$tmpRef and $srcRef = $tmpRef;

	if (! defined $input) {
	    $self->setErr(-1,$hint);
	    $result = -1;
	} else {
	    $newDataRef->{$field} = $input;
	}
    }

    ($stat,$err) = $self->status;

    if (! $stat) {
	$dsetObj->param($recNum, $newDataRef);     # add/update record number

	($stat,$err) = $dsetObj->status;
	$stat and die "\n * * Ouch: $err\nabort ";
    }

    return $result;
}

sub editLoadValue
{   my($self,$dsetName,$field,$text,$edit,$hint,$value,$bufferRef) = @_;

    return $value if $edit eq "skip";        # FIX: make this CONSISTENT!

    my $input = $value ||"";

    my $invalid = ( $edit ? ( $input =~ /$edit/ ? 0 : 1 ) : 0 );

    if ($invalid) {
	print "  * * expecting $hint\n";
	return( undef,"" );
    }

    my $DB   = $self->Base;
        my $mode = "Add";         ### $self->{OptsObj}->get("Mode");

    #print "DEBUG: calling applyEditPolicy for input='$input'\n";

    # Note: the "bufferRef" used to collect up the user's input
    # is now passed through to the "applyEditPolicy" method.
    # This allows for more complex policy edits then before.
    #
    my($stat,$error,$srcRef) = 
	$DB->applyEditPolicy($mode,$dsetName,$field,$input,$bufferRef);

    if ($stat) {
	print "  * * Oops: $error\n";
	return( undef,"" );
    }

    return( $input, $srcRef );
}

sub promptForUpdateValue
{   my($self,$dsetName,$field,$text,$edit,$hint,$default,$bufferRef) = @_;

    my($input,$notValid) = ("",1);
    my($stat,$error)     = (0,"");
    my $srcRef           = "";

    my $DB       = $self->Base;
    my $mode     = $self->{OptsObj}->get("Mode");

    while ($notValid) {

	$input = $self->promptLoop($text,$edit,$hint,$default);

	if (0) {
	   print "DEBUG:  orig='$default'\n";
	   print "DEBUG: input='$input'\n";
	}

	#_____________________________________________________
	# WARN: Do we want to retain this check? This assumes
	#       that any "default" entries are valid. Is okay?
	#       (It's okay when we are updating and defaults
	#       are coming from the existing file record.)
	#
	## return $input  if (($input ne "") and ($input eq $default));

	return $input  if (($mode =~ /^[Uu]pdate/) and ($input eq $default)) ;
	#_____________________________________________________

	return $input  if $input =~ m#^(/|//)$#;

	$stat = 0;

	#print "DEBUG: calling applyEditPolicy for input='$input'\n";

	# Note: the "bufferRef" used to collect up the user's input
	# is now passed through to the "applyEditPolicy" method.
	# This allows for more complex policy edits then before.
	#
	($stat,$error,$srcRef) = 
	    $DB->applyEditPolicy($mode,$dsetName,$field,$input,$bufferRef);

	# DEBUG:
	#$srcRef ||= "";
	#print "DEBUG: srcRef='$srcRef' in 'FOO'\n";

	if ($stat) {
	    print "\n * * Oops: $error\n\n";
	} else {
	    $notValid = 0;
	}

    }
    return( $input, $srcRef );
}

sub formatResult
{   my($self, $dset,$key,$value) = @_;

    my $DB       = $self->Base;
    my $dsetObj  = $DB->dset( $dset );

    my $dsetTitle= $dsetObj->dsetTitle;

    if ($value eq "dump_") {
	#
	# Useful information for DEBUG:
	#
	print "\nDumping 'ctrl fields' for data set $dset\n";
	print "Data set contains ", $dsetObj->count, " entries\n\n";

	#print $dsetObj->dump(0,-1);   # display ctrl fields
	print $dsetObj->dump(0,1);   # display ctrl fields and 1st record
	print "\n";
	return;
    }

    print "\n";
    print "Accessing $dset: lookup $key = '$value'\n";

    $dsetObj->indexInit( $key) unless $dsetObj->activeKey( $key );

    my $recNum     = $dsetObj->recNumber( $key, $value );
    my($stat,$err) = $dsetObj->status;

    unless ( defined $recNum and  length($recNum) ) {
	print "\n * * Oops: $key of '$value' not found in $dset\n";
	$stat and print " * * Ouch: $err\n";
	print "\n";
	return;
    }

    my $hashRef = $dsetObj->recEntry( $recNum );

  # foreach (keys %$hashRef) { print "  $_ = $hashRef->{$_}\n" }

    print "Found entry at record number ". ($recNum + 1) ."\n\n";

    my $text = "";
    my(@dataFields)= $dsetObj->ctrl('dataFields');    # FIX: add a method

    $self->{Defaults}->{$key} = $value;

    foreach my $key (@dataFields) {

	$text = $dsetObj->fieldPrompt( $key ) || $key;
	$text = String->justifyRight( "${text}: ", 20 );

	print "$text ". ($hashRef->{$key} ||"") ."\n";

	$self->{Defaults}->{$key} = $hashRef->{$key} if $hashRef->{$key};
    }
    print "\n";

    return $recNum;
}

#-----------------------------------------------------------------------
#   Start of Options module used to parse cmd-line input values
#-----------------------------------------------------------------------

package PTools::SDF::DBUtil::Options;
 use strict;

 my $Pack = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.01';
#@ISA     = qw( );

 use Getopt::Long 2.17;                      # requires 2.17 or later for -vvv
     Getopt::Long::Configure("bundling");    # must enable "bundling" for -vvv

sub new {
    my($class,$paramRef) = @_;

    my $self = bless {}, ref($class)||$class;
    $self->setErr(0,"");

    my $usage   = $self->setUsage;
    my $options = $self->setOptArgs;

    if (! GetOptions($self, @{ $options }) ) {
        print "\n$usage\n";
        $self->setErr(-1,"GetOptions detected errors");

    } elsif (@ARGV) {
        my $parameters = ($#ARGV == 0 ? "parameter" : "parameters");
        print "Unknown $parameters: @ARGV\n\n$usage\n";
        $self->setErr(-1,"Unknown $parameters: @ARGV");

    } else {
        $self->verifyOpts( $paramRef );
    }
    return $self unless wantarray;
    return($self, $self->status);
}


sub set    { $_[0]->{$_[1]}=$_[2]         }   # note that the 'param' method
sub get    { return( $_[0]->{$_[1]}||"" ) }   # combines both 'set' and 'get'
sub param  { $_[2] ? $_[0]->{$_[1]}=$_[2] : return( $_[0]->{$_[1]}||""   )  }
sub setErr { return( $_[0]->{_status}=$_[1]||0, $_[0]->{_error}=$_[2]||"")  }
sub status { return( $_[0]->{_status}||0, $_[0]->{_error}||"" )             }
sub stat   { ( wantarray ? ($_[0]->{_error}||"") : ($_[0]->{_status} ||0) ) }
sub err    { return($_[0]->{_error}||"")                                    }

sub verbose { return( $_[0]->get('verbose') ) }
sub usage   { return( $_[0]->get('_usage')  ) }
sub debug   { return( $_[0]->get('debug')   ) }

sub queryMode  { return( $_[0]->{Mode} eq "query"  ? 1 : 0 ) }
sub addMode    { return( $_[0]->{Mode} eq "add"    ? 1 : 0 ) }
sub updateMode { return( $_[0]->{Mode} eq "update" ? 1 : 0 ) }
sub loadMode   { return( $_[0]->{Mode} eq "load"   ? 1 : 0 ) }
sub needLock   { return( $_[0]->{Mode} ne "query"  ? 1 : 0 ) }
sub mode       { return( $_[0]->{Mode}     ||"" ) }

sub loadFile   { return( $_[0]->{load}     ||"" ) }
sub dataBase   { return( $_[0]->{base}     ||"" ) }
sub dataSet    { return( $_[0]->{dset}     ||"" ) }
sub inputFile  { return( $_[0]->{_fileObj} ||"" ) }
sub fileObj    { return( $_[0]->{_fileObj} ||"" ) }
sub force      { return( $_[0]->{force}    ||"" ) }
sub quiet      { return( $_[0]->{quiet}    ||"" ) }


sub setUsage
{   my($self) = @_;

    my $prog  = Global->get('basename');       # name of this script
    my $usage = <<"--EndOfUsage--";
  Usage: $prog  [ <options> ]

  Where options include

    [ { -a | --add    }            ]  # add entries to data set(s)
    [ { -u | --update }            ]  # update existing entries
    [ { -l | --load   } <dataFile> ]  # add entries from a data file

  Notes: the default run mode is 'query'
	 options 'a', 'u' and 'l' are mutually exclusive
         option 'l' requires use of the 'd' option

    [ { -b | --base   } <dataBase> ]  # specify alternate SDF Data Base
    [ { -d | --dset   } <dataSet>  ]  # specify the data set to 'load'

    [ { -h | --help   }            ]  # display usage and quit
    [ { -V | -VV[V]   }            ]  # display version information
--EndOfUsage--

  # [ { -q | --quiet  }            ]  # run quietly (only w/ -F <dataFile>)
  # [ { -f | --force  }            ]  # force all answers to 'yes'
  # [ { -s | --server } <hostName> ]  # select alternate LDAP server
  # [ { -v | -vvv     }            ]  # increase the verbose level
  # [ { -D | --Debug  }            ]  # use "test user" passwd input

    return $self->set('_usage', $usage);
}

sub setOptArgs
{   my($self) = @_;
    #________________________________________
    # Migration Args (for syntax see Getopt::Long module)
    #
    my @optArgs = (
		  "base|b=s",
		  "dset|d=s",
                  "load|l=s",
                  "force|f",
                  "quiet|q",
                  "help|h",
                  "server|s=s",
		  "add|a",
		  "update|u",
                  "verbose|Verbose|v+",
                  "debug|D|Debug|DEBUG",
                  "version|Version|V+",
                  );

    #________________________________________
    # Additional Args
    #
  # push(@optArgs,
  #               "force|F|Force|FORCE",
  #               );

    return $self->set('_optArgs', \@optArgs);
}

sub verifyOpts
{   my($self,$paramRef) = @_;

    #_______________________
    # This first bit provides override capability for
    # user entered cmd-line parameters
    #
    if (ref $paramRef) {
        foreach (keys %$paramRef) {
            #print "DEBUG: verifyOpts: override '$_' => $paramRef->{$_}\n";
            $self->{$_} = $paramRef->{$_};
        }
    }

    #_______________________________________
    # Reformat and verify options entered
    #
    # die "Options 'q' and 'v' are mutually exclusive\n$usage\n"
    #   if ($self->{'q'} and $self->{'v'});

    if ($self->{add} and $self->{update}) { 
	print "Options 'add' and 'update' are mutually exclusive.\n\n";
	print $self->usage ."\n"; 
	exit(1);
    }
    $self->{Mode} = "query";
    $self->{Mode} = "add"    if ($self->{add});
    $self->{Mode} = "update" if ($self->{update});
    $self->{Mode} = "load"   if ($self->{load});

    $self->{Mode} || die "Ouch: Unknown mode in '$Pack'";

    $self->{base}  or $self->{base} = $self->{DefaultBase} ||"";
    if ($self->{base}) {
	$self->{base}  =~ s#\.pm$##;
	$self->{base}  =~ s#/#::#g;
	$self->{base}  =~ /^PTools::SDF::/ 	
	    or $self->{base} = "PTools::SDF::" . $self->{base};
    }
    Loader->use( $self->{base} );

    if ($self->{help})    { print "\n". $self->usage ."\n"; exit(0); }
    if ($self->{version}) { print "\n". $self->version;     exit(0); }

    $self->{verbose} and $self->{verbose} *= 2;    # multiply level by 2
    $self->{verbose}  or $self->{verbose}  = 1;    # default for verbose,
  # $self->{quiet}   and $self->{verbose}  = 0;    # if not "quiet" mode

    #_______________________________________
    # Are we loading from a data file?
    #
    my $loadFile = $self->loadFile;

    if ($loadFile) {

	if ($self->addMode) {
	    print "Options 'add' and 'load' may not be used together.\n\n";
	    print $self->usage ."\n"; 
	    exit(1);
	} elsif ($self->updateMode) {
	    print "Options 'update' and 'load' may not be used together.\n\n";
	    print $self->usage ."\n"; 
	    exit(1);
	} elsif (! $self->dataSet) {
	    print "Option 'load' requires using the '-d <dataSet>' option.\n\n";
	    print $self->usage ."\n"; 
	    exit(1);
	}

        my($fileObj,$stat,$err) = new PTools::SDF::SDF( $loadFile );

        if ($stat) {
            $self->setErr($stat, "$loadFile: $err");

        } else {
            $fileObj->sort( undef, 'uname' ) if $fileObj->isSortable;

            $self->set('_fileObj', $fileObj );
        }
    }
    # die $self->dump;

    return;
}


sub version
{   my($self,$base) = @_;

    # The user's "data base schema" class was loaded up in the
    # 'verifyOpts' method ... Here we make the User's DB the
    # default.
    #
    $base ||= $self->{base};
    $base  =~ s#::#/#go;
    $base .= ".pm";

    my($width,$ver,$count,@modules) = (0,"",0,());
    my(@allModules) = (sort keys %INC);
    my $totalCount  = $#allModules + 1;

    if ($self->{version} == 1) {                   # -V
        $width     = 20;
        (@modules) = $base;
        (@modules) or (@modules) = ("SDF/DB.pm");
    } else {                                       # -VV[V]
        $width     = $self->{version} == 2 ? 35 : 45;
        (@modules) = (@allModules);
    }
    no strict "refs";

    my $text = "";
    foreach my $module (@modules) {
        if ($self->{version} < 3) {                # -VVV
	   #next unless defined $INC{$module};
            next unless $INC{$module} =~ m#/SDF/#;
        }
        $module =~ s#/#::#go;
        $module =~ s/\.pm$//o;

        ($ver) = ${$module."::VERSION"} || "";
        $text .= sprintf("%-${width}s %5s\n", $module, $ver);
        $count++
    }
    if ($self->{version} > 1) {
        $text .= "\nVersion list shown includes $count of $totalCount modules.\n";
        if ($self->{version} < 3) {
            my $basename = Global->get('basename');
            $text .= "For list of all modules run:  $basename -VVV\n";
        }
    }
    $text .= "\n";

    return $text;
}

sub dump
{   my($self) = @_;
    my($text)= "DEBUG: ($Pack)\n";
    $text   .= "  self='$self'\n";
    my($pack,$file,$line)=caller();
    my($status,$error)= $self->status;
    $text .= "CALLER $pack at line $line ($file)\n";
    $text .= " status = $status\n";
    $text .= " error  = $error\n";
  # $text .= " usage  = $self->{_usage}\n" if $self->{_usage};
  # $text .= "\n";
    foreach (sort keys %$self) {
        next if $_ =~ /^_/;
        $text .= " $_ = $self->{$_}\n";
    }
    $text .= "____________\n";
    return($text);
}
#_________________________
1; # Required by require()
