use Data::Dumper;
use ExchangeRates;

my $hash = {};
ExchangeRates::main( "2017-01-01", "2017-01-02", \$hash );
#print Dumper $hash;

