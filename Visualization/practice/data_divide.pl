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

our $hash;
printf("loading...");
$hash = eval read_file( "./data.perldb" );
printf("done\n");

our $ref;
my $min;
my $curr;
my $prev;

grep 
{
    /^0?(\d+):0?(\d+)/;
    $min = $1*60+$2;

    $curr = $hash->{$_}[0];

    printf "%s %03d %.2f\n", substr($_, 0, 5), $min, $hash->{$_}[0];

    $prev = $curr;
}
sort keys %$hash;

my $data;
my $m_last = 24*60; #minutes
for (my $m = 0; $m < $m_last; $m+= 10)
{
    $data->{$m} = 1;
    #print "$m\n";
}


