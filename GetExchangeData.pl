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
use LWP::UserAgent;
use HTML::TableExtract;

use IO::Handle;
STDOUT->autoflush(1);
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

our $URL = "http://srh.bankofchina.com/search/whpj/search.jsp";
our $ua = LWP::UserAgent->new( 
            timeout => 5, keep_alive => 1, agent => 'Mozilla/5.0',
          );

our %hash :shared;
our @task :shared;
$hash = shared_clone( {} );

my $from = time_to_date(time() - 24*3600*5);
my $to   = time_to_date(time());

my $pageid = 1;
my @ths;
grep { push @ths, threads->create( \&func, $from, $to, $_ ) } ( 0 .. 5 );

#循环插入任务，等待线程结束
while ( threads->list( threads::running ) ) 
{
    grep { $task[$_] = $pageid++ if ( $task[$_] == 0 ); } (0..5);
}

#分离线程
grep { $_->detach() } @ths;

write_file( "hash.perldb", { binmode => ":raw" }, Dumper \%hash );
printf("Done\n");

sub func
{
    my ($from, $to, $idx) = @_;
    my $content;
    
    while (1)
    {
        if ( $task[$idx] == 0 ) { sleep 0.1; next; }

        $content = get_page( $from, $to, $task[$idx] );
        $content =~/var m_nCurrPage = (\d+)/;
        last if ( $1 != $task[$idx] );

        printf "[%d] mission: %d\n", $idx, $task[$idx];
        get_info( $content );

        #归零
        $task[$idx] = 0;
    }
}

sub get_info 
{
    our %hash;
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
        $hash{ $timestamp } = shared_clone([ @$row ]);
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

