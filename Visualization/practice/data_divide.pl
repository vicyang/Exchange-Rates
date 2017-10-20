=info
    数据平摊
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

my $mins;
for my $k ( sort keys %$hash )
{
    $mins = minutes($k);
    printf "%s %-3d %.2f\n", $k, $mins, $hash->{$k}[3];
}

sub minutes
{
    $_[0] =~ /^0?(\d+):0?(\d+)/;
    return $1*60+$2;
}