# -*- Perl -*-
#
# File:  PTools/SDF/RPC/DBServer.pm
# Desc:  A lightweight service to allow remote access to SDF DB files
# Date:  Tue Nov 19 18:47:09 2002
# Stat:  Prototype, Experimental
#
# Abstract:
#        This is an abstract base class that provides remote
#        access to a given SDF "data base" via "RPC::PlServer".
#
#        A concrete subclass must be created that defines the 
#        specific access for each "data base."  
#        Blah, blah, blah ... E.g., "PTools::SDF::RPC::DemoDB"
#
#        This class is constructed such that every client will
#        specify the same 'PTools::SDF::RPC::DBServer' value for 
#        tye server 'application' as defined in the RPC::PlClient
#        man page.
#

package PTools::SDF::RPC::DBServer;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.05';
 @ISA     = qw( RPC::PlServer );

 use RPC::PlServer;         # ISA RPC::PlServer, ISA Net::Daemon
#use PTools::Date::Format;  # $dateStr = time2str("%c", time);

sub run
{   my($class,$hashRef) = @_;
    #
    # Here we apply any defaults passed in through the $hashRef
    # argument to the default "$configRef" configuration hash.
    # Then we start a new server using the configuration hash.
    #
    my $configRef = $class->_reconfig( $hashRef );

    my $server = $PACK->new( $configRef );

    $server->Bind();

    $@ and die "Ouch: $@";
}

sub _reconfig
{   my($class,$hashRef) = @_;

    my $configRef = {
	    # 
	    # WARN: the following is only a partial implementation
	    # of the required parameters for starting the server.
	    # The remaining params MUST be passed from a subclass
	    # See PTools::SDF::RPC::DemoDBServer and RPC::PlServer for more.
	    #
        'methods'    => {
	    #
	    # All PTools::SDF::RPC::ClientDB classes use the 
            # "PTools::SDF::RPC::DBServer" string for the 'application' 
            # designator, as defined in the "RPC::PlClient" man page.
	    #
            'PTools::SDF::RPC::DBServer' => {   # Clients: use for 'application'
                  'ClientObject'  => 1,
                  'CallMethod'    => 1,
                  'NewHandle'     => 1,
                         },

             'PTools::SDF::DB' => {
		# Include all methods from the following classes.
		# Note that the actuall invoking concrete server
		# subclass must be aliased to this sub-hash for
		# the following method calls to work. See the
		# hack, er ... workaround ... below.
		# .  PTools::SDF::DB
		#
		'advisoryLock'    => 0,
		'lock'            => 0,

		'advisoryUnlock'  => 1,
		'applyEditPolicy' => 1,
		'baseName'        => 1,
		'dataBaseFile'    => 1,
		'dataBaseLock'    => 1,
		'dataBaseName'    => 1,
		'dataBaseSchema'  => 1,
		'dataFile'        => 1,
		'dataSet'         => 1,
		'dataSetAliases'  => 1,
		'dataSetFields'   => 1,
		'dataSetFile'     => 1,
		'dataSetKeys'     => 1,
		'dataSetList'     => 1,
		'dataSetLock'     => 1,
		'dataSetName'     => 1,
		'dataSetNames'    => 1,
		'dataSetSchema'   => 1,
		'dataSetTitle'    => 1,
		'datafile'        => 1,
		'dataset'         => 1,
		'dbaseName'       => 1,
		'dset'            => 1,
		'dsetAliases'     => 1,
		'dsetFields'      => 1,
		'dsetFile'        => 1,
		'dsetKeys'        => 1,
		'dsetList'        => 1,
		'dsetLock'        => 1,
		'dsetName'        => 1,
		'dsetNames'       => 1,
		'dsetTitle'       => 1,
		'dump'            => 1,
		'fieldEdit'       => 1,
		'fieldHint'       => 1,
		'fieldPrompt'     => 1,
		'fieldText'       => 1,
		'fullAliasList'   => 1,
		'getEditPolicy'   => 1,
		'initialize'      => 1,
		'isLocked'        => 1,
		'loadSchema'      => 1,
		'new'             => 1,
		'notLocked'       => 1,
		'openDataSet'     => 1,
		'primarySetList'  => 1,
		'prompt'          => 1,
		'promptUser'      => 1,
		'schemaVersion'   => 1,
		'setErr'          => 1,
		'status'          => 1,
		'unlock'          => 1,
                         },

             'PTools::SDF::DSET' => {
		# Include all methods from the following classes.
		# .  PTools::SDF::DSET
		# .  PTools::SDF::IDX
		# .  PTools::SDF::ARRAY
		# .  PTools::SDF::SDF
		# .  PTools::SDF::File

		# Disable all 'save' methods by default to 
		# ensure data files are read-only. This is
		# overridden, below, when requested by the
		# invoking subclass.
		#
		'lock'            => 0,
		'save'            => 0,
		'saveFile'        => 0,
		'_saveFile'       => 0,
		'writeLogFile'    => 0,

		'METHOD::ABSTRACT'=> 1,
		'_loadFileSDF'    => 1,
		'activeKey'       => 1,
		'activeKeys'      => 1,
		'applyEditPolicy' => 1,
		'compoundInit'    => 1,
		'count'           => 1,
		'ctrl'            => 1,
		'ctrlDelete'      => 1,
		'ctrlFields'      => 1,
		'ctrlParam'       => 1,
		'dataBaseName'    => 1,
		'dataBaseSchema'  => 1,
		'dataFields'      => 1,
		'dataSetAliases'  => 1,
		'dataSetFields'   => 1,
		'dataSetFile'     => 1,
		'dataSetKeys'     => 1,
		'dataSetNames'    => 1,
		'dataSetPath'     => 1,
		'dataSetSchema'   => 1,
		'dataSetTitle'    => 1,
		'delete'          => 1,
		'dsetAliases'     => 1,
		'dsetFields'      => 1,
		'dsetFile'        => 1,
		'dsetKeys'        => 1,
		'dsetName'        => 1,
		'dsetPath'        => 1,
		'dsetTitle'       => 1,
		'dump'            => 1,
		'err'             => 1,
		'errOnly'         => 1,
		'escape'          => 1,
		'escapeIFS'       => 1,
		'expand'          => 1,
		'extend'          => 1,
		'extended'        => 1,
		'fieldDelete'     => 1,
		'fieldEdit'       => 1,
		'fieldEdit '      => 1,
		'fieldHint'       => 1,
		'fieldNames'      => 1,
		'fieldPrompt'     => 1,
		'fieldText'       => 1,
		'get'             => 1,
		'getErr'          => 1,
		'getError'        => 1,
		'getIndex'        => 1,
		'getIndexEntry'   => 1,
		'getPrompt'       => 1,
		'getPrompts'      => 1,
		'getRecEntry'     => 1,
		'hasData'         => 1,
		'idxUpd'          => 1,
		'import'          => 1,
		'index'           => 1,
		'indexCount'      => 1,
		'indexDelete'     => 1,
		'indexInit'       => 1,
		'indexUpdate'     => 1,
		'isEmpty'         => 1,
		'isLocked'        => 1,
		'isSortable'      => 1,
		'keyFields'       => 1,
		'keyNames'        => 1,
		'loadFile'        => 1,
		'new'             => 1,
		'noData'          => 1,
		'notEmpty'        => 1,
		'notLocked'       => 1,
		'notSortable'     => 1,
		'param'           => 1,
		'primaryKeys'     => 1,
		'prompt'          => 1,
		'promptUser'      => 1,
		'recData'         => 1,
		'recEntry'        => 1,
		'recNumber'       => 1,
		'recParam'        => 1,
		'reset'           => 1,
		'resetActiveKeys' => 1,
		'schemaName'      => 1,
		'set'             => 1,
		'setActiveKey'    => 1,
		'setErr'          => 1,
		'setError'        => 1,
		'setSchema'       => 1,
		'sort'            => 1,
		'stat'            => 1,
		'statOnly'        => 1,
		'status'          => 1,
		'unescape'        => 1,
		'unescapeIFS'     => 1,
		'unextend'        => 1,
		'unlock'          => 1,
		'unset'           => 1,
		'updateFields'    => 1,
		'updateFieldsViaIndex' => 1,
                         },
            },
	};

    # Override the above with the requested default values
    #
    foreach (keys %$hashRef) {
	$configRef->{$_} = $hashRef->{$_};
	#print "DEBUG: set $_ => $configRef->{$_}\n";
    }

    # Enable the "real data base class" for remote access
    #
    my $dbClass = $hashRef->{SDF_DB_CLASS} 
	|| die "No SDF_DB_CLASS argument passed";

    # Reach down and grab a configRef for the generic Data Base class
    # and copy the result into a config element for the DB class that
    # is used to implement this DB Server.
    #
    my $dbConfigRef = $configRef->{'methods'}->{'PTools::SDF::DB'};
    $configRef->{'methods'}->{$dbClass} = $dbConfigRef;

    # Finally, if we have been given permission, enable
    # remote "data base" for write access (effective for
    # every data set defined in a given SDF DB).

    if ($hashRef->{SDF_DB_WRITE}) {
	# WARNING: THIS STEP ENABLES REMOTE WRITE ACCESS TO THE DATA BASE
	# Use the Data Base configRef we grabbed in the last step, above,
	# and tweak it to allow the various "lock" methods.
	#
	$dbConfigRef->{'lock'}             = 1;
	$dbConfigRef->{'advisoryLock'}     = 1;

	# Reach down and grab a configRef for the generic Data Set class
	# and tweak it to allow the various "lock" and "save" methods.
	#
	my $dsetConfigRef = $configRef->{'methods'}->{'PTools::SDF::DSET'};
	$dsetConfigRef->{'lock'}           = 1;
	$dsetConfigRef->{'save'}           = 1;
	$dsetConfigRef->{'saveFile'}       = 1;
	$dsetConfigRef->{'_saveFile'}      = 1;
	$dsetConfigRef->{'writeLogFile'}   = 1;
    }

    if (0) {
	my $write = ($hashRef->{SDF_DB_WRITE} ? "ENABLED" : "Disabled" );
	print "--------------------------------------------------------\n";
	##my $date  = PTools::Date::Format->time2str( "%c", time );
	##print "Starting up server: $date\n";
	print "Configuring server: application  = \"$PACK\"\n";
	print "Configuring access: remote write = $write\n";
	print "Enabling data base: local SDF DB = $dbClass\n";
    }
    return $configRef;
}
#_________________________
1; # Required by require()

__END__

# ToDo: Add "POD" template here for "manpage" documentation.

