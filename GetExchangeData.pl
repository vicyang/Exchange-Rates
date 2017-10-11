=info
    获取中行外汇牌价-美元栏目的信息
    Auth: 523066680
    Date: 2017-10
    https://github.com/vicyang/Exchange-Rate
=cut

use strict;
use LWP::Simple;
use Encode;
use IO::Handle;
STDOUT->autoflush(1);

our $data = [];
our $di = -1;
our @all;

our $FH;
my $stream;
open $FH, ">:raw:crlf", "record.txt" or die "$!";
$FH->autoflush(1);

my $A = "2017-09-01";
my $B = "2017-09-30";
my $i = 1;
my $curpg;
my $prvpg = -1;

while (1)
{
    print "Getting Page: $i\n";
    @all=();
    $stream = get(  
                "http://srh.bankofchina.com/search/whpj/search.jsp?" .
                "erectDate=${A}&nothing=${B}&pjname=1316".
                "&page=$i"
            );  #unicode            
    
    $stream =~/var m_nCurrPage = (\d+)/;
    $curpg = $1;
    last if ($curpg == $prvpg);    #页面并不会因为页码超出范围而404，超出后会指向有效的最后一页
                                   #如果返回页码和上次一致，判定为结束
    
    @all=split('\n', $stream);
    get_info();

    $i++;
    $prvpg = $curpg;
}

close $FH;

<STDIN>;

sub get_info 
{
    our @all;
    our $FH;

    my ($i, @arr);

    $i=0;
    foreach (@all) 
    {
        if (/th>(.*)<\/th>/) 
        {
            $arr[$i++]=encode('gbk',$1);
        }
    }

    #获取美元信息
    my $spec = decode('utf-8',"<td>美元<\/td>");
    my $begin = 0;
    my $j = 0;

    foreach (0..$#all) 
    {
        if ($all[$_]=~/$spec/i) 
        {
            $begin=1;
            print $FH "\n";
        }
        if ($begin==1 and $j < $i )
        {
            next if ($all[$_]=~/^\s+$/); #如果是空行
            $all[$_]=~/td>(.*)<\/td>/i;
            print $FH encode('gbk',$1), "\t";
            $j++;
        } 
        if ($all[$_]=~/<\/tr>/)   #末尾重置
        {
            $j=0;
            $begin=0;
        }
    }
}

