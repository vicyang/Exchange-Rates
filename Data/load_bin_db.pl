use autodie;
use Storable;
use Encode;
use Time::HiRes qw/sleep/;
use Data::Dumper;
use Data::Dump qw/dump/;

our $DB_File = "./all_in_one.perldb.bin";
printf "Loading ...";
our $hash = retrieve( $DB_File );
printf "Done ...";

dump $hash;