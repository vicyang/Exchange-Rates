=info
    获取中行外汇牌价-美元栏目的信息
    Auth: 523066680
    Date: 2017-10
    https://github.com/vicyang/Exchange-Rate
=cut

use strict;
use Encode;
use Time::Local;
use LWP::UserAgent;
use Data::Dumper qw/Dumper/;
use IO::Handle;
STDOUT->autoflush(1);

our $data = [];
our $di = -1;
our @all;

our $FH;
open $FH, ">:raw", "history.txt" or die "$!";
$FH->autoflush(1);

our $ua = LWP::UserAgent->new(
            keep_alive=>1,
            timeout=>5,
            agent => 'Mozilla/5.0',
          );

my $from = time_to_date(time() - 24*3600*1);
my $to   = time_to_date(time());               # today

my $i = 1;
my $curpg;
my $prvpg = -1;
my $res;

while (1)
{
    print "Getting Page: $i\n";
    @all=();

    $res = $ua->post(
            "http://srh.bankofchina.com/search/whpj/search.jsp",
            [
                erectDate => $from,
                nothing   => $to,
                pjname    => "1316",
                page      => $i
            ]
        );

    $res->content() =~/var m_nCurrPage = (\d+)/;
    $curpg = $1;
    last if ($curpg == $prvpg);    #页面并不会因为页码超出范围而404，超出后会指向有效的最后一页
                                   #如果返回页码和上次一致，判定为结束
    
    @all = split('\n', $res->content());
    get_info();

    $i++;
    $prvpg = $curpg;
}

close $FH;
printf("Done\n");


sub get_info 
{
    our @all;
    our $FH;

    my ($i, @arr);

    $i = 0;
    for (@all) 
    {
        if (/th>(.*)<\/th>/) 
        {
            $arr[$i++] = $1;
        }
    }

    #获取美元信息
    my $spec = "<td>美元<\/td>";
    my $begin = 0;
    my $j = 0;

    for my $idx ( 0 .. $#all ) 
    {
        if ( $all[$idx] =~/$spec/i ) 
        {
            $begin = 1;
            print $FH "\r\n";
        }
        if ( $begin == 1 and $j < $i )
        {
            next if ($all[$idx]=~/^\s+$/); #如果是空行
            $all[$idx]=~/td>(.*)<\/td>/i;
            print $FH $1, "\t";
            $j++;
        } 
        if ( $all[$idx] =~/<\/tr>/ )   #末尾重置
        {
            $j = 0;
            $begin = 0;
        }
    }
}

sub time_to_date
{
    my ($sec, $min, $hour, $day, $mon, $year) = localtime( shift );
    $mon += 1;
    $year += 1900;
    return sprintf "%d-%02d-%02d", $year,$mon,$day;
}
