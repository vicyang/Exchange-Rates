use Encode qw/from_to encode decode/;
use File::Slurp;
use HTML::TableExtract;
my $te = HTML::TableExtract->new();

my $html_str = read_file("page.html", { binmode => ":raw" } );
$te->parse( $html_str );

for my $ts ($te->tables) 
{
    print "Table (", join(',', $ts->coords), "):\n";
    printf "Rows:%d\n", $#{$ts->rows};
    for my $row ( $ts->rows )
    {
        for my $ele ( @$row )
        {
            $ele=~s/\s//g;
            print encode('gbk', decode('utf8', $ele )), "\t";
        }
        print "\n";
    }
    print "\n";
}

sub xcode 
{
    $_[1]='x' if (not defined $_[1]);

    for my $v ( split(//,$_[0]) ) 
    {
        print sprintf ("%02$_[1] ",ord($v)); 
    }
    print "\n";
}