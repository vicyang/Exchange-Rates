=info
    获取中行外汇牌价-美元栏目的信息
    Auth: 523066680
    Date: 2017-10
    https://github.com/vicyang/Exchange-Rates
=cut

use warnings "all";
use utf8;
use Encode;
use Time::HiRes qw/sleep/;
use Time::Local;
use File::Slurp;
use LWP::UserAgent;
use Mojo::UserAgent;
use IO::Handle;
STDOUT->autoflush(1);

our $url = "https://srh.bankofchina.com/search/whpj/search_cn.jsp";
our $ua = Mojo::UserAgent->new();
$ua = $ua->connect_timeout(10);

my %headers = (
'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
'Accept-Encoding' => 'gzip, deflate, br',
'Accept-Language' => 'zh-CN,zh;q=0.9',
'Cache-Control' => 'no-cache',
'Connection' => 'keep-alive',
'Content-Type' => 'application/x-www-form-urlencoded',
'Cookie' => 'JSESSIONID=0000Jlmv9AqeTE6QcPxZQQa7c6L:-1',
'Host' => 'srh.bankofchina.com',
'Origin' => 'https://srh.bankofchina.com',
'Pragma' => 'no-cache',
'Referer' => 'https://srh.bankofchina.com/search/whpj/search_cn.jsp?erectDate=2020-11-01&nothing=2020-11-02&pjname=%E7%BE%8E%E5%85%83&page=2',
'Sec-Fetch-Dest' => 'document',
'Sec-Fetch-Mode' => 'navigate',
'Sec-Fetch-Site' => 'same-origin',
'Sec-Fetch-User' => '?1',
'Upgrade-Insecure-Requests' => '1',
'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.66 Safari/537.36',
);

my $args = {
    erectDate => "2020-11-01",
    nothing   => "2020-11-02",
    pjname    =>  "美元",
    page => 1
};

my $res = $ua->post( $url, \%headers, form => $args )->result;
#my $res = $ua->get( "https://www.bankofchina.com", \%headers )->result;
print u2gbk($res->body);

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

sub gbk { encode('gbk', $_[0]) }
sub utf8 { encode('utf8', $_[0]) }
sub u2gbk { encode('gbk', decode('utf8', $_[0])) }
sub uni { decode('utf8', $_[0]) }
