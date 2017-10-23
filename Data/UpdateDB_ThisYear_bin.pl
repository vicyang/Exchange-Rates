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
use Storable;
use Data::Dumper;
use List::Util qw/sum/;
use LWP::UserAgent;
use HTML::TableExtract;

use IO::Handle;
STDOUT->autoflush(1);
$Data::Dumper::Indent = 0;

our $URL = "http://srh.bankofchina.com/search/whpj/search.jsp";
our $ua = LWP::UserAgent->new( 
            timeout => 5, keep_alive => 1, agent => 'Mozilla/5.0',
          );

our $hash :shared;
our @task :shared;
our $date :shared;
our $dt_key :shared;

my $to   = time_to_date( time() );
my $year = substr($to, 0, 4);
my $file = "$year.perldb.bin";
my $from = "$year-01-01";

$to = date_plus($to, -1);

if ( -e $file ) 
{
    print "Loading ... ";
    my $struct = retrieve( $file );
    $hash = shared_clone($struct);
    print "Done\n";
}
else { $hash = shared_clone( {} ) }; '初始化';

my @ths;
grep { push @ths, threads->create( \&func, $_ ) } ( 0 .. 5 );

my $time_a = Time::HiRes::time();
my $pageid;
$date = $from;

while ( $date le $to )
{
    $dt_key = $date;
    $dt_key =~s/-/\./g;
    printf "%s\n", $dt_key;

    if ( exists $hash->{$dt_key} ) 
    {
        $date = date_plus($date, 1);
        next;
    }

    $hash->{$dt_key} = shared_clone( {} );
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

sleep 0.1;  #给我0.1秒缓口气
grep { $_->kill('KILL')->detach() } @ths;

printf("Dumping ... ");
#线程共享的哈希表无法直接store，间接拷贝
my $db = eval Dumper( $hash );
store( $db, $file );
printf("Done\nTime used: %.3f\n", Time::HiRes::time() - $time_a );

sub func
{
    my ($idx) = @_;
    my $content;
    my $timestamp;
    $SIG{'KILL'} = sub { threads->exit() };
    
    while (1)
    {
        # 0: 等待指示;  -1: 等待下一回合 
        if ( $task[$idx] <= 0 ) { sleep 0.01; next; }

        $content = get_page( $date, $date, $task[$idx] );
        unless ($content =~/var m_nCurrPage = (\d+)/) { print "repeat\n"; next; }

        #如果提取日期和任务日期不一致，标记为-1
        if ( $1 != $task[$idx] ) { $task[$idx] = -1; next; }

        $timestamp = get_exchange_data( $content );
        unless ( defined $timestamp ) { $task[$idx] = -1; next; }
        printf "[%d] mission: %2d time: %s\n",
                $idx, $task[$idx], $timestamp;
        
        $task[$idx] = 0;    #任务清零
    }
}

sub get_exchange_data
{
    my ( $html_str ) = @_;
    our $dt_key;
    my ($obj, $table, $timestamp, $date, $time);

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
        $timestamp =~/^(.{10}) (.{8})/;
        ($date, $time) = ($1, $2);
        $hash->{$date}{$time} = shared_clone( [@$ele] );
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

