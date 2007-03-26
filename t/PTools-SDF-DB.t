#########################

use Test::More tests => 11;

BEGIN { use_ok('PTools::SDF::DB') };
BEGIN { use_ok('PTools::SDF::DBPolicy') };
BEGIN { use_ok('PTools::SDF::DBUtil') };
BEGIN { use_ok('PTools::SDF::DemoDBClient') };
BEGIN { use_ok('PTools::SDF::DemoDB') };
BEGIN { use_ok('PTools::SDF::DSET') };
TODO: {
    local $TODO = "Must have demo classes here...Fix this";
      { use_ok('PTools::SDF::DBClient') };
      { use_ok('PTools::SDF::RPC::DBClient') };
}
BEGIN { use_ok('PTools::SDF::RPC::DBServer') };
BEGIN { use_ok('PTools::SDF::RPC::DemoDB') };
BEGIN { use_ok('PTools::SDF::RPC::DemoDBServer') };
#########################
