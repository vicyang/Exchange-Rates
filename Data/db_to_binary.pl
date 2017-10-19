use Storable qw/store retrieve/;
use File::Basename;
use File::Slurp;
use Time::HiRes qw/time/;
use IO::Handle;
STDOUT->autoflush(1);

my @files = glob "*.perldb";
grep { func($_) } @files;

sub func
{
    my $file = shift;
    my $hashref;
    my $dest;
    $dest = $file.".bin";

    printf("[eval] loading $file...");
    $hashref = eval read_file( $file );
    printf("Done\n");

    store $hashref, $dest;
}
