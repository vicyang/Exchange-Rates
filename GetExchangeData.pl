=info
    获取中行外汇牌价-美元栏目的信息
    Auth: 523066680
    Date: 2017-10
    https://github.com/vicyang/Exchange-Rates
=cut

use Encode;
use Time::Local;
use File::Slurp;
use LWP::UserAgent;
use HTML::TableExtract;

use IO::Handle;
STDOUT->autoflush(1);

our $URL = "http://srh.bankofchina.com/search/whpj/search.jsp";
our $FH;
open $FH, ">:raw", "history.txt" or die "$!";

our $ua = LWP::UserAgent->new( 
            timeout => 5, keep_alive => 1, agent => 'Mozilla/5.0',
          );

my $from = time_to_date(time() - 24*3600*1);
my $to   = time_to_date(time());               # today

my $pageid = 1;
my $content;

while (1)
{
    print "Getting Page: $pageid\n";
    $content = get_page( $from, $to, $pageid );

    #页码超出后会指向有效的最后一页而非404，实际页码不同步时结束循环
    $content =~/var m_nCurrPage = (\d+)/;
    last if ( $1 != $pageid );

    get_info( $content );
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
    grep { $table = $_ } $obj->tables;

    for my $row ( $table->rows )
    {
        next if ( $row->[1] eq '' );  #表格最末一行为空
        grep { print encode('gbk', decode('utf8', $_)), "\t" } @$row;
        print "\n";
    }
}

sub get_page
{
    our $ua;
    my ($from, $to, $pageid) = @_;
    my $res;
    $res = $ua->post( 
        $URL,
        [
            erectDate => $from,
            nothing   => $to,
            pjname    => "1316",
            page      => $pageid
        ]
    );
    return $res->content();
}

sub time_to_date
{
    my ($sec, $min, $hour, $day, $mon, $year) = localtime( shift );
    $mon += 1;
    $year += 1900;
    return sprintf "%d-%02d-%02d", $year,$mon,$day;
}

