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
$Data::Dumper::Indent = 0;
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
my $to   = "2017-01-01";

if ( -e $file ) 
{
    print "Loading ... ";
    $hash = shared_clone(eval read_file( $file, binmode => ':raw' ));
    print "Done\n";
}
else { $hash = shared_clone( {} ) }; '初始化';

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
    
    #循环插入任务，当指定日期下的所有页面获取完毕，结束循环
    while ( sum(@task) != -6 )
    {
        grep { $task[$_] = $pageid++ if ( $task[$_] == 0 ); } (0..5);
    }

    #日期迭代
    $date = date_plus($date, 1);
}

#线程分离
grep { $_->detach() } @ths;

printf("Dumping ... ");
my $dbstr = Dumper($hash);
$dbstr =~s/\[\{/[\r\n  {/g;
$dbstr =~s/(\]\},)/$1\r\n  /g;
$dbstr =~s/(\}\],)/$1\r\n/g;
write_file( $file, { binmode => ":raw" }, $dbstr );
printf("Done\n");

sub func
{
    my ($idx) = @_;
    my $content;
    my $timestamp;
    
    while (1)
    {
        # 0: 等待指示;  -1: 等待下一回合 
        if ( $task[$idx] <= 0 ) { sleep 0.1; next; }

        $content = get_page( $date, $date, $task[$idx] );
        $content =~/var m_nCurrPage = (\d+)/;

        #如果提取日期和任务日期不一致，标记为-1
        if ( $1 != $task[$idx] ) { $task[$idx] = -1; next; }

        $timestamp = get_exchange_data( $content );
        printf "[%d] mission: %2d time: %s\n",
                $idx, $task[$idx], $timestamp;
        
        $task[$idx] = 0;    #任务清零
    }
}

sub get_exchange_data
{
    my ( $html_str ) = @_;
    our $data;
    my ($obj, $table, $timestamp);

    #count => 1 表示选择第二个表格
    $obj = HTML::TableExtract->new( depth => 0, count => 1 );
    $obj->parse($html_str);

    grep { $table = $_ } $obj->tables;

    for my $ele ( $table->rows )
    {
        shift @$ele;                       '去掉第一行抬头';
        next if ( $ele->[1] eq '' );       '去掉第一列货币类型';
        next if ( not $ele->[1] =~/\d/ );  '表格最后一行为空';

        $timestamp = pop @$ele;
        push @{$hash->{$date}}, shared_clone( { $timestamp , [@$ele]} );
        #push @{$hash->{$date}}, shared_clone({$timestamp, join("\t", @$row)});
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

sub date_plus
{
    my ($date, $days) = @_;
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

