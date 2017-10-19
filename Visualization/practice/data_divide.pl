=info
    时间段平摊
    Auth: 523066680
    Date: 2017-10
    https://github.com/vicyang/Exchange-Rates
=cut

use Encode;
use File::Slurp;
use Data::Dumper;
use List::Util qw/sum min max/;

use IO::Handle;
STDOUT->autoflush(1);

printf("loading...");
our $hash = eval read_file( "./data.perldb" );
printf("done\n");

grep 
{
    /^0?(\d+):0?(\d+)/;
    printf "%s %d\n", substr($_, 0, 5), $1*60+$2;
} sort keys %$hash;

my $data;
my $min_max = 24*60;
for (my $min = 0; $min < $min_max; $min+= 10)
{
    $data->{$min} = 1;
}


