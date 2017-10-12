=info
    获取中行外汇牌价-美元栏目的信息
    Auth: 523066680
    Date: 2017-10
    https://github.com/vicyang/Exchange-Rates
=cut

use Encode;
use Time::Local;
use File::Slurp;
use Data::Dumper;
use LWP::UserAgent;
use HTML::TableExtract;

use IO::Handle;
STDOUT->autoflush(1);
$Data::Dumper::Indent = 1;

our $URL = "http://srh.bankofchina.com/search/whpj/search.jsp";
our $FH;
open $FH, ">:raw", "history.txt" or die "$!";

our $ua = LWP::UserAgent->new( 
            timeout => 5, keep_alive => 1, agent => 'Mozilla/5.0',
          );
our $hash;

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

    write_file( "hash.txt", {binmode=>":raw:crlf"}, Dumper $hash );
}

close $FH;
printf("Done\n");

sub get_info 
{
    our $hash;
    my $html_str = shift;

    # count => 1 表示选择第二个表格。
    my $obj = HTML::TableExtract->new( depth => 0, count => 1 );
    $obj->parse($html_str);

    my $table;
    grep { $table = $_ } $obj->tables;

    my $timestamp;
    for my $row ( $table->rows )
    {
=info
    去掉第一行抬头
    去掉第一列货币类型
    表格最后一行为空
=cut
        shift @$row;
        next if ( $row->[1] eq '' );
        next if ( not $row->[1] =~/\d/ );

        $timestamp = pop @$row;
        $hash->{ $timestamp } = [ @$row ];
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

