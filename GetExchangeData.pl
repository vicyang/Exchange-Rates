=info
    获取中行外汇牌价-美元栏目的信息
    Auth: 523066680
    Date: 2017-10
    https://github.com/vicyang/Exchange-Rate
=cut

use Encode;
use Time::Local;
use File::Slurp;
use LWP::UserAgent;
use HTML::TableExtract;

use IO::Handle;
STDOUT->autoflush(1);

our $data = [];
our $di = -1;
our @all;

our $FH;
open $FH, ">:raw", "history.txt" or die "$!";
$FH->autoflush(1);

our $ua = LWP::UserAgent->new( 
                timeout => 5,
                keep_alive => 1, 
                agent => 'Mozilla/5.0',
          );

my $from = time_to_date(time() - 24*3600*1);
my $to   = time_to_date(time());               # today

my $pageid = 1;
my $curr;
my $prev = -1;
my $res;
my $s;

while (1)
{
    print "Getting Page: $pageid\n";
    @all = ();

    $res = $ua->post(
            "http://srh.bankofchina.com/search/whpj/search.jsp",
            [
                erectDate => $from,
                nothing   => $to,
                pjname    => "1316",
                page      => $pageid
            ]
        );

    #页码超出后会指向有效的最后一页，若页码和上次一致，判定为结束
    $res->content() =~/var m_nCurrPage = (\d+)/;
    $curr = $1;
    last if ($curr == $prev);

    get_info( $res->content() );
    $prev = $curr;
    $pageid++;
}

close $FH;
printf("Done\n");


sub get_info 
{
    my $html_str = shift;
    # count => 1 表示选择第二个表格。
    my $obj = HTML::TableExtract->new( depth => 0, count => 1 );
    $obj->parse($html_str);

    my $table;
    my $date;
    grep { $table = $_ } $obj->tables;

    for my $row ( $table->rows )
    {
        next if ( $row->[1] eq "" or (not $row->[2] =~/\d/) );
        print encode('gbk', decode('utf8', shift @$row )), "\t";
        $date = pop @$row; 
        grep { printf "%.2f\t", $_ } @$row;
        print "$date\n";
    }
}

sub time_to_date
{
    my ($sec, $min, $hour, $day, $mon, $year) = localtime( shift );
    $mon += 1;
    $year += 1900;
    return sprintf "%d-%02d-%02d", $year,$mon,$day;
}

