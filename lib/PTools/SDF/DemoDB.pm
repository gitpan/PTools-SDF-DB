# -*- Perl -*-
#
# File:  PTools/SDF/DemoDB.pm
# Desc:  Manage ascii data files (data sets) as a simple data base
# Auth:  Chris Cobb, Hewlett-Packart, Cupertino, CA  <cobb@cup.hp.com>
# Date:  Thu Jun 27 09:36:05 2002
# Stat:  Prototype
#
# Abstract:
#        This class maniuplates a collection of data file "wrappers."
#
#        This class works as a "singleton" object. The first call to
#        the "new method will create an object of this class. Each
#        subsequent call to "new" method returns the original object.
#
#        In addition, this is a "factory class" that creates and caches
#        objects to manipulate individual files in the "data base." The
#        "data set objects" also act as "singleton" objects. They are
#        instantiated upon first access only. After that, the existing
#        "open" data set object is returned.
#
#        Locking strategy: Currently an "advisory lock" is obtained on
#        one single file to lock the entire "data base" during updates.
#
#        At some point this may change to allow for locking one or more
#        data sets. This will require care to ensure a consistent order
#        in which files are locked and, if lock error occur, to ensure
#        any locks applied before the error are released.
#
# Synopsis:
#
#        use PTools::SDF::DemoDB;
#
#        $DB = new PTools::SDF::DemoDB;      # no "data sets" opened yet
#
#        $userMasterObj = $DB->dset('UserMaster');   # open a "data set"
#
#        $mgrMasterObj  = $DB->dset('ManagerMaster');    # open another
#
#
#        At this point, any subsequent calls to the "new" method will
#        return the original "$DB" object. Also, any subsequent calls to 
#        the "dset" method for either of the two "open data sets" will 
#        return the original object corresponding to that file name.
#
#        This mechanism allows any subroutine in any calling module to 
#        access the same open "data set" objects w/o passing parameters.
#
#        Additional calls to the "dset" method using other data set
#        file names will continue to open the additional files.
#
#
#        print "Locking data base ... ";
#        if ($DB->advisoryLock) { print "ok\n" } else { die "NOT\n" }
#        
#        [  perform data set updates ... don't forget to "save"  ]
#
#        print "Unlocking data base ... ";
#        if ($DB->advisoryUnlock) { print "ok\n" } else { die "NOT\n" }
#
#
# Note:  The "data set" files don't need to be "closed." During the
#        "open" process they are copied into memory. After performing
#        any updates the calling module must call the "save" method on
#        each modified file to make permanent changes.
#
#        Also, if a "data base" lock is in effect, simply exiting the 
#        script will release the lock.
#

package PTools::SDF::DemoDB;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.01';
 @ISA     = qw( PTools::SDF::DB );

#use PTools::Local;
 use PTools::SDF::DB;

#my $LocalObjName = 'app_DemoDB';


sub new
{   my($class,@params) = @_;
  
  # # If an object of this class has already been instantiated
  # # then return it. If not, create one, cache it and return it.
  # my $self = PTools::Local->get( $LocalObjName );
  #
  # if (! ref $self) {
  #	bless $self = &loadSchema, ref($class)||$class;
  #	$self->SUPER::initialize;
  #	PTools::Local->set( $LocalObjName, $self);
  # }

    bless my $self = &loadSchema(@params), ref($class)||$class;
    $self->SUPER::initialize;

    return $self;
}

sub loadSchema
{   my($class,$dataDir) = @_;

    # Define a few miscellaneous variables prior to the schema
    #
  # my $dataDir = PTools::Local->param('app_datdir');

    $dataDir ||= "/nethome/cobb/source/perl/tools/global/data/";


 # Define the data base schema
 #
 my $schema = {  # BEBIN Schema

    DataBase => {
	BaseName   => 'Demo of SDF Data Base System',
	DataFile   => "$dataDir/SDF/DemoDB",
	PriDataSet => [ qw( UserMaster ) ],
	Contacts   => [ qw( jeniti@cup.hp.com cobb@cup.hp.com ) ],

    },  # END DataBase

    DataSet => {

      UserMaster => {
	DataFile => "$dataDir/SDF/UserMaster",

	Title    => 'User Master File',
	Aliases  => [ qw( usrmast ) ],
	Keys     => [ qw( uname empnum acctuid ) ],
	PriKeys  => [ qw( uname ) ],
	Fields   => [ qw( uname acctstat acctuid acctgid empnum active hpemp
			  empfirst emplast empbldg empgeoloc emptelnet empemail
			  empshell emphome lastchanged mgrempnum ) ],
	Field => {
	  Text => {
          uname => 'Owner Uname',
       acctstat => 'Acct Status',
        acctuid => 'Acct UserID',
        acctgid => 'Acct GroupID',
         empnum => 'Emp Number',
         active => 'Active Emp',
          hpemp => 'HP Employee',
       empfirst => 'First Name',
        emplast => 'Last Name',
        empbldg => 'Building',
      empgeoloc => 'Geo Loc',
      emptelnet => 'Emp Telnet',
       empemail => 'Emp E-Mail',
        emphome => 'Emp HomeDir',
       empshell => 'Emp Shell',
    lastchanged => 'Last Change',
      mgrempnum => 'Mgr EmpNum',
	  }, # END Field=>Text

	  Edit => {
          uname => '^([a-z])\w{0,7}$',
       acctstat => '^([^:]*)$',                  # anything but ":"
        acctuid => '^\d{1,5}$',                  # 0 to 99999
        acctgid => '^\d{1,5}$',                  # 0 to 99999
         empnum => '^(\d{8,8}|N\d{7,7})$',       # nnnnnnnn or Nnnnnnnn,
         active => '^(|([01]))$',                # null, 0 or 1
          hpemp => '^(|([01]))$',                # null, 0 or 1
       empfirst => '^([^:]*)$',                  # anything but ":"
        emplast => '^([^:]*)$',                  # anything but ":"
        empbldg => '^([^:]*)$',                  # anything but ":"
      empgeoloc => '^([^:]*)$',                  # anything but ":"
      emptelnet => '^(|\d{3}-\d{4})$',           # null or xxx-xxxx
       empemail => '^([^:]*)$',                  # anything but ":"
       empshell => '^(/bin/|/usr/bin/)\w+$',     # /bin/xxx or /usr/bin/xxx
        emphome => '^([^:]*)$',                  # anything but ":"
    lastchanged => '^\d{9,11}$',                 # a 9- to 11-digit number
      mgrempnum => '^\d{8,8}$',                  # an 8-digit number
	  }, # END Field=>Edit

	  Hint => {
          uname => 'up to eight lower case chars; must start with a letter',
       acctstat => 'any characters except a colon (":")',
        acctuid => 'a 1 to 5 digit number',
        acctgid => 'a 1 to 5 digit number',
         empnum => 'an 8 digit number (or 7 digits with a leading "N")',
         active => 'a 0 or 1, or <null>',
          hpemp => 'a 0 or 1, or <null>',
       empfirst => 'any characters except a colon (":")',
        emplast => 'any characters except a colon (":")',
        empbldg => 'any characters except a colon (":")',
      empgeoloc => 'any characters except a colon (":")',
      emptelnet => 'a telnet number (nnn-nnnn) or <null>',
       empemail => 'any characters except a colon (":")',
       empshell => 'either "/bin/xxx" or "/usr/bin/xxx"',
        emphome => 'any characters except a colon (":")',
    lastchanged => 'a 9 to 11 digit number',
      mgrempnum => 'an 8 digit number',
	  }, # END Field=>Hint

	}, # END Field

	Policy => {
	}, # END Policy

      }, # END UserMaster
      #---------------------------------------------------------------------

      ManagerMaster => {
	DataFile   => "$dataDir/SDF/ManagerMaster",

	Title   => 'Manager Master File',
	Aliases => [ qw( mgrmast ) ],
	Keys    => [ qw( mgrempnum ) ],
	PriKeys => [ qw( mgrempnum ) ],
	Fields  => [ qw( mgrempnum mgrfirst mgrlast mgremail mgrtelnet
                       mgrbldg mgrgeoloc mgrdept ) ],
	Field => {
          Text => {
      mgrempnum => 'Mgr EmpNum',
       mgrfirst => 'First Name',
        mgrlast => 'Last Name',
       mgremail => 'E-Mail',
      mgrtelnet => 'Telnet',
        mgrbldg => 'Building',
      mgrgeoloc => 'Geo Loc',
        mgrdept => 'Dept Code',
	  }, # END Field=>Text

	  Edit => {
      mgrempnum => '^(\d{8,8})$',       # nnnnnnnn or Nnnnnnnn,
       mgrfirst => '.*',
        mgrlast => '.*',
       mgremail => '.*',
      mgrtelnet => '^(|\d{3}-\d{4})$',
        mgrbldg => '.*',
      mgrgeoloc => '.*',
        mgrdept => '.*',
	  }, # END Field=>Edit

	  Hint => {
      mgrempnum => 'an 8 digit number',
      mgrtelnet => 'a telnet number (nnn-nnnn) or null',
	  }, # END Field=>Hint

	}, # END Field

	Policy => {
	}, # END Policy

      }, # END ManagerMaster
      #---------------------------------------------------------------------

      GenericAccounts => {
	DataFile   => "$dataDir/SDF/GenericAccounts",

	Title   => 'Generic Accounts File',
	Aliases => [ qw( genacct ) ],
	Keys    => [ qw( acct_uname ) ],
	PriKeys => [ qw( acct_uname ) ],
	Fields  => [ qw( acct_uname uname acct_desc ) ],

	Field => {
          Text => {
     acct_uname => 'Acct Uname',
          uname => 'Owner Uname',
      acct_desc => 'Description',
	  }, # END Field=>Text

	  Edit => {
     acct_uname => '^([a-z])\w{0,7}$',
          uname => '^([a-z])\w{0,7}$',
      acct_desc => '^([^:]*)$',
	  }, # END Field=>Edit

	  Hint => {
     acct_uname => 'up to eight lower case chars; must start with a letter',
          uname => 'up to eight lower case chars; must start with a letter',
      acct_desc => 'any characters except a colon (":")',
	  }, # END Field=>Hint

	}, # END Field

	Policy => {
	}, # END Policy

      }, # END GenericAccounts
      #---------------------------------------------------------------------

      SuperuserAccounts => {
	DataFile   => "$dataDir/SDF/SuperuserAccounts",

	Title   => 'Superuser Accounts File',
	Aliases => [ qw( sysacct ) ],
	Keys    => [ qw( acct_uname ) ],
	PriKeys => [ qw( acct_uname ) ],
	Fields  => [ qw( acct_uname uname ) ],

	Field => {
          Text => {
     acct_uname => 'Acct Uname',
          uname => 'Owner Uname',
	  }, # END Field=>Text

	  Edit => {
     acct_uname => '^([a-z])\w{0,7}$',
          uname => '^([a-z])\w{0,7}$',
	  }, # END Field=>Edit

	  Hint => {
     acct_uname => 'up to 8 characters; must start with a lower-case letter',
          uname => 'up to 8 characters; must start with a lower-case letter',
	  }, # END Field=>Hint

	}, # END Field

	Policy => {
	}, # END Policy

      }, # END SuperuserAccounts
      #---------------------------------------------------------------------

      UserViewSpace => {
	DataFile   => "$dataDir/SDF/UserViewSpace",

	# Note the "compound index" used in this data set: The
	# "key field" doesn't actually exist in the data file.

	Title   => 'User Viewspace File',
	Aliases => [ qw( usrview ) ],
	Keys    => [ qw( uname&ringname ) ],
	PriKeys => [ qw( uname&ringname ) ],
	Fields  => [ qw( uname ringname viewhost ringpri allocation ) ],

	Field => {
          Text => {
'uname&ringname'=> 'Uname&Ring',      # prompt for 'compound index' field
          uname => 'Acct Uname',
       ringname => 'Ring Name',
       viewhost => 'View Host',
        ringpri => 'Ring Priority',
     allocation => 'Space Alloc',
	  }, # END Field=>Text

	  Edit => {
          uname => '^([a-z])\w{0,8}$',        # 0 to 8 lower-case characters
       ringname => '^([a-z])\w{0,8}$',        # 0 to 8 lower-case characters
       viewhost => '^([a-z])\w{0,8}$',        # 0 to 8 lower-case characters
        ringpri => '^(|([12]))$',              # null, 1, 2
     allocation => '^([0-9]{1,2})\.?([0-9]?)$', # 0 to 99.9 GB
	  }, # END Field=>Edit

	  Hint => {
          uname => 'up to 8 characters; must start with a lower-case letter',
       ringname => 'up to 8 characters; must start with a lower-case letter',
       viewhost => 'up to 8 characters; must start with a lower-case letter',
        ringpri => 'one of "1" (1st pri), "2" (2nd pri) or <null>',
     allocation => 'from 0 to 99.9 (Gigabytes); only one decimal digit',
	  }, # END Field=>Hint

	}, # END Field

	Policy => {
	}, # END Policy

      }, # END UserViewSpace
      #---------------------------------------------------------------------

    },  # END DataSet

 };  # END Schema

    return( $schema );
}
#_________________________
1; # Required by require()

__END__

# Example Data Set Definition

      DataSetName => {
	DataFile   => "$dataDir/SDF/DataSetName",

	Title   => 'Data Set Name',
	Aliases => [ qw( setname ) ],
	Keys    => [ qw( keyfield ) ],
	PriKeys => [ qw( keyfield ) ],
	Fields  => [ qw( keyfield otherfield anotherfield ) ],

	Field => {
          Text => {
	  }, # END Field=>Text

	  Edit => {
	  }, # END Field=>Edit

	  Hint => {
	  }, # END Field=>Hint

	}, # END Field

	Policy => {
	}, # END Policy

      }, # END DataSetName
      #---------------------------------------------------------------------

