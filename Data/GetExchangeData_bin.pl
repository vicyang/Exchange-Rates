﻿=info
    获取中行外汇牌价-美元栏目的信息
    Auth: 523066680
    Date: 2017-10
    https://github.com/vicyang/Exchange-Rates
=cut


use Modern::Perl;
use utf8;
use Encode;
use Storable qw/store/;
use threads;
use threads::shared;
use Try::Tiny;
use Time::HiRes qw/sleep/;
use Time::Local;
use Data::Dumper;
use File::Slurp;
use LWP::UserAgent;
use IO::Handle;
STDOUT->autoflush(1);

BEGIN
{
	use FindBin;
	use lib $FindBin::Bin . "/lib";
	use HTML::TableExtract;
}

our $URL = "https://srh.bankofchina.com/search/whpj/search_cn.jsp";
our $ua = LWP::UserAgent->new( 
            timeout => 5, keep_alive => 1, agent => 'Mozilla/5.0',
          );

our $hash :shared;
our @task :shared;
$hash = shared_clone( {} );

while ( check_input( @ARGV ) == 0 ) { @ARGV = ask() }
my ($from, $to, $file) = @ARGV;

my $time_a = Time::HiRes::time();
my $pageid = 1;
my @ths;
@task = (0)x6;
grep { push @ths, threads->create( \&func, $from, $to, $_ ) } ( 0 .. 5 );

#循环插入任务，等待线程结束
while ( threads->list( threads::running ) ) 
{
    grep { $task[$_] = $pageid++ if ( $task[$_] == 0 ); } (0..5);
}

#分离线程
grep { $_->detach() } @ths;

#线程共享的hash需要导出副本才可以成功store（不知道原因）
my $hashref = eval Dumper $hash;
printf("Dumping ... ");
store( $hashref, $file );
printf("Done\nTime used: %.3f\n", Time::HiRes::time() - $time_a );

sub func
{
    my ($from, $to, $idx) = @_;
    my $content;
    my $timestamp;
    
    while (1)
    {
        if ( $task[$idx] == 0 ) { sleep 0.01; next; }

        $content = get_page( $from, $to, $task[$idx] );
        #如果获取信息失败，重新get_page
        unless ($content =~/var m_nCurrPage = (\d+)/) {
            printf "[%d] Try again: %4d\t<-\n", $idx, $task[$idx];
            next; 
        }

        #如果页码和任务页码不匹配，结束任务
        last if ( $1 != $task[$idx] );
        $timestamp = get_exchange_data( $content );
        
        #如果该页没有任何有效信息，结束任务
        last if ( not defined $timestamp );

        printf "[%d] mission: %4d time: %s\n", 
                $idx, $task[$idx], $timestamp;
        #归零
        $task[$idx] = 0;
    }
}

sub get_exchange_data
{
    my ( $html_str ) = @_;
    my ($obj, $table, $timestamp, $date, $time);

    #count => 1 表示选择第二个表格
    $obj = HTML::TableExtract->new( depth => 0, count => 1 );
    $obj->parse($html_str);
    grep { $table = $_ } $obj->tables;

    for my $ele ( $table->rows )
    {
        shift @$ele;                        #去掉第一行抬头
        next if ( not defined $ele->[1] );  #表格最后一行为空 ["\xA0", undef, undef, ...
        next if ( $ele->[1] !~ /\d/ );      #略过标题行

        $timestamp = pop @$ele;
        $timestamp =~/^(.{10}) (.{8})/;
        ($date, $time) = ($1, $2);
        if (not exists $hash->{$date}) { $hash->{$date} = shared_clone( {} ) }
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
            pjname    => utf8("美元"),  #2021-06 值1316，更新为美元
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

sub check_input
{
    if ( $#_ < 2 ) {
        printf "Missing parameters\n";
        return 0;
    }

    my ( $from, $to, $file) = @_;
    my $today = time_to_date( time() );
    my $res = 1;

    for my $dt ( $from, $to )
    {
        if ( $dt =~/(\d{4})-(\d{2})-(\d{2})/ )
        {
            $res = 0 if ( $dt gt $today );
            $res = 0 if ( $1 lt 2007 );
            try   { timelocal(0,0,0, $3, $2-1, $1-1900) } 
            catch { $res = 0 };
        }
        else
        {
            $res = 0;
        }
    }

    $res = 0 if ( $from gt $to );
    if ($res == 0) { printf "wrong format\n" }

    return $res;
}

sub ask
{
    my @args;
	printf "Usage(example): GetExchangeData_bin.pl 2016-01-01 2016-12-31 2016.db\n";
	printf "From:";
    push @args, scalar(<STDIN>);
    printf "To:";
    push @args, scalar(<STDIN>);
    printf "File name:";
    push @args, scalar(<STDIN>);
    grep { s/\r?\n$// } @args;
    return @args;
}

sub gbk { encode('gbk', $_[0]) }
sub utf8 { encode('utf8', $_[0]) }
sub u2gbk { encode('gbk', decode('utf8', $_[0])) }
sub uni { decode('utf8', $_[0]) }
