=info
    Perl Data Memory Test
    Auth: 523066680
    Date: 2017-10
    https://github.com/vicyang/Exchange-Rates
=cut

use Encode;
use File::Slurp;
use Data::Dumper;

use IO::Handle;
STDOUT->autoflush(1);
$Data::Dumper::Indent = 0;

my $hash;
my $file = "exchange_rates.perldb";
if ( not -e $file ) { exit; }


print "Loading ... ";
$hash = eval read_file( $file, binmode => ':raw' );
print "Done\n";


=info
实测 8M文件 加载后内存 140M 左右
而多线程版本加载后 500MB 左右
=cut

#%$hash = ();
grep { print "."; sleep 1 } (1..10);
print "\nFree ... ";

# for my $k ( keys %$hash )
# {
#     #print $k, "\n";
#     for my $e ( @{$hash->{$k}} )
#     {
#         my ($kk) = keys %$e;
#         @{$e->{$kk}} = ();
#         %$e = ();
#     }
#     @{$hash->{$k}} = ();
# }

%$hash = ();

print "Done\n";
grep { print "."; sleep 1 }(1..10);
