=info
    多个数据合并
=cut

use Storable;
use File::Slurp;
use Time::HiRes qw/time/;
use IO::Handle;
STDOUT->autoflush(1);

my @files = glob "*.perldb.bin";
my $all = {};

grep { load($_, $all) } @files;

printf("[Storable] Dumping ... ");
store $all, "all_in_one.perldb.bin";
printf("Done\n");

sub load
{
    my ($file, $all) = @_;
    my $hashref;

    printf("[eval] loading $file...");
    $hashref = retrieve( $file );
    printf("Done\n");

    for my $k ( keys %$hashref )
    {
        $all->{$k} = $hashref->{$k};
    }
    #store $hashref, $dest;
}
