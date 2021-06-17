=info
=cut

use utf8;
use Encode;
use Modern::Perl;
use File::Slurp;
use Time::HiRes 'sleep';
use Date::Format;
use Storable;
use List::Util qw/max min sum/;

use Cwd;
use Win32::OLE qw (in with CP_UTF8);
use Win32::OLE::Const ('Microsoft Excel');
use Win32::OLE::Variant;
$Win32::OLE::CP = CP_UTF8;
STDOUT->autoflush(1);

my $exfile = gbk("ExchangeRates.xlsx");
my $fold = getcwd();  #完整路径
   $fold=~s/\//\\/;
my ($ex, $status) = load_excel();
my $book = $ex->Workbooks->open( $fold ."\\". $exfile );

my $sh = $book->Worksheets(3);
my $history = retrieve "./2009.perldb.bin";
my $r = 1;
for my $e ( sort keys %$history )
{
    my $sum = sum( map { $history->{$e}{$_}[2] } keys %{$history->{$e}} );
    my $min = min( map { $history->{$e}{$_}[2] } keys %{$history->{$e}} );
    printf "%s %s\n", $e, $min ;
    $sh->Cells($r, 'B')->{Value} = $e;
    $sh->Cells($r, 'C')->{Value} = $min/100;
    $r++;
}

done($book, $status);

sub load_excel
{
    # use existing instance if Excel is already running
    my $status;
    eval { $ex = Win32::OLE->GetActiveObject('Excel.Application') };
    die "Excel not installed" if $@;

    if ( defined $ex ) {
        $status = "exist";
    } else {
        $status = "new";
        $ex = Win32::OLE->new('Excel.Application', "Quit") or die "Oops, cannot start Excel";
    }

    return ($ex, $status);
}

sub done
{
    my ($book, $status) = @_;
    # save and exit
    #$ex->{DisplayAlerts} = 'False';
    $book->Save();
    $book->close() if $status eq "new";
    undef $book;
    undef $ex;
}

sub gbk { encode('gbk', $_[0]) }
sub utf8 { encode('utf8', $_[0]) }
sub u2gbk { encode('gbk', decode('utf8', $_[0])) }
sub uni { decode('utf8', $_[0]) }
