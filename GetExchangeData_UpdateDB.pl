=info
    获取中行外汇牌价-美元栏目的信息
    Auth: 523066680
    Date: 2017-10
    https://github.com/vicyang/Exchange-Rates
=cut

use Encode;
use threads;
use threads::shared;
use Time::HiRes qw/sleep/;
use Time::Local;
use File::Slurp;
use Data::Dump qw/dump/;
use Data::Dumper;
use List::Util qw/sum/;
use LWP::UserAgent;
use HTML::TableExtract;

use IO::Handle;
STDOUT->autoflush(1);
$Data::Dumper::Indent = 1;
#$Data::Dumper::Sortkeys = 1;

our $URL = "http://srh.bankofchina.com/search/whpj/search.jsp";
our $ua = LWP::UserAgent->new( 
            timeout => 5, keep_alive => 1, agent => 'Mozilla/5.0',
          );

our $hash :shared;
our @task :shared;
our $date :shared;

my $file = "exchange_rates.perldb";
my $from = "2016-05-02";
my $to   = "2016-12-10";

if ( -e $file ) 
{
    $hash = shared_clone(eval read_file( $file, binmode => ':raw' ));
}
else { $hash = shared_clone( {} ) } #初始化


#创建线程
my @ths;
grep { push @ths, threads->create( \&func, $_ ) } ( 0 .. 5 );

my $pageid;
$date = $from;

while ( $date le $to )
{
    printf "%s\n", $date;
    if ( exists $hash->{$date} ) 
    {
        $date = date_plus($date, 1);
        next;
    }

    $hash->{$date} = shared_clone( [] );
    $pageid = 1;

    @task = (0) x 6;
    #循环插入任务，等待线程结束
    do
    {
        grep { $task[$_] = $pageid++ if ( $task[$_] == 0 ); } (0..5);
    }
    until ( sum(@task) == -6 );

    $date = date_plus($date, 1);
}

#分离线程
grep { $_->detach() } @ths;

write_file( $file, { binmode => ":raw" }, Dumper $hash );
printf("Done\n");

sub func
{
    my ($idx) = @_;
    my $content;
    my $timestamp;
    
    while (1)
    {
        #0 表示等待指示，-1表示等待下一回合
        if ( $task[$idx] <= 0 ) { sleep 0.1; next; }

        $content = get_page( $date, $date, $task[$idx] );
        $content =~/var m_nCurrPage = (\d+)/;
        if ( $1 != $task[$idx] ) { $task[$idx] = -1; next; }

        $timestamp = get_exchange_data( $content );
        printf "[%d] mission: %2d time: %s\n",
                $idx, $task[$idx], $timestamp;
        #归零
        $task[$idx] = 0;
    }
}

sub get_exchange_data
{
    my ( $html_str ) = @_;

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
        #push @{$hash->{$date}}, shared_clone( { $timestamp , [@$row]} );
        push @{$hash->{$date}}, shared_clone({$timestamp, join("\t", @$row)});
    }

    return $timestamp;
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

#============================================================
#                       日期处理函数
#============================================================

sub date_plus
{
    my ($date, $days) = @_;
    #转为time格式（从1970年1月1日开始计算的秒数）
    my ($year, $mon, $day) = map { $_=~s/^0//; $_ } split("-", $date);
    my $t = timelocal(0, 0, 0, $day, $mon-1, $year)
            + $days * 24 * 3600;

    return time_to_date( $t );
}

sub time_to_date
{
    my ($sec, $min, $hour, $day, $mon, $year) = localtime( shift );
    $mon += 1;
    $year += 1900;
    return sprintf "%d-%02d-%02d", $year,$mon,$day;
}

