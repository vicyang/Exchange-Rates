=info
    外汇牌价-数据可视化
    Auth: 523066680
    Date: 2017-10
    https://github.com/vicyang/Exchange-Rates
=cut

use utf8;
use autodie;
use Storable;
use Encode;
use Font::FreeType;
use Time::HiRes qw/sleep/;
use Time::Local;
use File::Slurp;
use Data::Dumper;
use List::Util qw/sum min max/;

use IO::Handle;
use OpenGL qw/ :all /;
use OpenGL::Config;
use feature 'state';

STDOUT->autoflush(1);

BEGIN
{
    our $WinID;
    our $HEIGHT = 500;
    our $WIDTH  = 750;
    our ($rx, $ry, $rz, $zoom) = (0.0, 0.0, 0.0, 1.0);

    our $DB_File = "nearly.perldb";
    printf("loading...");
    if (not -e $DB_File) {
        system("perl ../Data/GetExchangeData.pl 2017-10-18 2017-10-20 $DB_File");
    }

    our $hash = eval read_file( $DB_File );
    our @days = (sort keys %$hash);
    our ($MIN, $MAX) = (1000.0, 0.0);
    
    for my $d (@days)
    {
        for my $t ( keys %{$hash->{$d}} )
        {
            if ($hash->{$d}{$t}[3] < $MIN) { $MIN = $hash->{$d}{$t}[3] }
            if ($hash->{$d}{$t}[3] > $MAX) { $MAX = $hash->{$d}{$t}[3] }
        }
    }

    printf("Done.\n");
    printf("min: %.3f, max: %.3f\n", $MIN, $MAX );

    our $tobj;
    our ($font, $size) = ("C:/windows/fonts/msyh.ttf", 32);
    our $dpi = 100;
    our $face = Font::FreeType->new->face($font);
    $face->set_char_size($size, $size, $dpi, $dpi);
}

INIT
{
    our %TEXT;
    print "Loading contours ... ";
    my $code;
    my $char;
    foreach $code (0x00..0x7F)
    {
        $char = chr( $code );
        $TEXT{ $char } = get_contour( $char ); 
    }

    foreach $char (split //, "年月日期数据")
    {
        $TEXT{ $char } = get_contour( $char ); 
    }
    print "Done\n";
}

=struct
    $hash = {
        'day1' => { 'time1' => [@data], 'time2' => [@data] }, 
        'day2' => { ... }, ...
     }
=cut

&main();

sub display 
{
    state @times;
    state $day;
    state $i = 0;
    state ($min, $max);
    our ($hash, @days, $MIN);
    my $hour, $time, $last;
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glColor3f(0.8, 0.8, 0.8);
    if ( $i % 500 == 0 )
    {
        $day = shift @days;
        unless ( defined $day ) {
            glutDestroyWindow( $WinID );
            exit;
        }

        #时间清零，避免受到上一次影响
        @times = ();
        @rates = ();
        #时间排序
        @times = sort keys %{ $hash->{$day} };
        @rates = map { $hash->{$day}{$_}[3] } @times;
        ($min, $max) = ( min(@rates), max(@rates) );
        printf("%s, count: %d, avg: %.3f\n", $day, $#rates+1, sum(@rates)/($#rates+1) );
    }

    $i++;

    glPushMatrix();
    glScalef( $zoom, $zoom, $zoom );
    glRotatef($rx, 1.0, 0.0, 0.0);
    glRotatef($ry, 0.0, 1.0, 0.0);
    glRotatef($rz, 0.0, 0.0, 1.0);

    glColor3f(1.0, 1.0, 0.3);
    glBegin(GL_LINE_STRIP);
    grep 
    {
        /^0?(\d+):0?(\d+)/;
        $time = ($1 * 60.0 + $2)/2.0 - $WIDTH/2.0 + 10.0;
        glVertex3f($time, ($hash->{$day}{$_}[3]-$MIN)*10.0 , 0.0);
    }
    @times;

    #补足长度
    #glVertex3f(360.0, ($hash->{$day}{$times[-1]}[3]-$MIN)*10.0 - $HEIGHT/2.0 , 0.0);
    glEnd();

    glutStrokeHeight(GLUT_STROKE_MONO_ROMAN);
    grep 
    {
        /^0?(\d+):0?(\d+)/;
        $time = ($1 * 60.0 + $2)/2.0 - $WIDTH/2.0 + 10.0;
        glVertex3f(100.0, 0.0, 0.0);
        glPushMatrix();
            glTranslatef($time, -100.0, 0.0);
            glRotatef(90.0, 0.0, 1.0, 0.0);
            glRotatef(90.0, 0.0, 0.0, 1.0);
            glScalef(0.1, 0.1, 0.1);
            #glutStrokeString(GLUT_STROKE_MONO_ROMAN, substr($_, 0, 5));
            glutStrokeString(GLUT_STROKE_MONO_ROMAN, $hash->{$day}{$_}[3]);

        glPopMatrix();
    }
    @times;

    glPopMatrix();
    glutSwapBuffers();
}

sub idle 
{
    sleep 0.02;
    glutPostRedisplay();
}

sub init
{
    glClearColor(0.0, 0.0, 0.0, 0.5);
    glPointSize(1.0);
    glLineWidth(1.0);
    glEnable(GL_BLEND);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_POINT_SMOOTH);
    glEnable(GL_LINE_SMOOTH);

    $tobj = gluNewTess();
    gluTessCallback($tobj, GLU_TESS_BEGIN,     'DEFAULT');
    gluTessCallback($tobj, GLU_TESS_END,       'DEFAULT');
    gluTessCallback($tobj, GLU_TESS_VERTEX,    'DEFAULT');
    gluTessCallback($tobj, GLU_TESS_COMBINE,   'DEFAULT');
    gluTessCallback($tobj, GLU_TESS_ERROR,     'DEFAULT');
    gluTessCallback($tobj, GLU_TESS_EDGE_FLAG, 'DEFAULT');
}

sub reshape 
{
    my ($w, $h) = (shift, shift);
    #Same with screen size
    state $hz_half = $WIDTH/2.0;
    state $vt_half = $HEIGHT/2.0;
    state $fa = 1000.0;

    glViewport(0, 0, $w, $h);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(-$hz_half, $hz_half, -$vt_half, $vt_half, 0.0, $fa*2.0); 
    #gluPerspective( 90.0, 1.0, 1.0, $fa*2.0 );
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    gluLookAt(0.0,0.0,$fa, 0.0,0.0,0.0, 0.0,1.0, $fa);
}

sub hitkey 
{
    our $WinID;
    my $k = lc(chr(shift));
    if ( $k eq 'q') { quit() }
    if ( $k eq 'w') { $rx+=10.0 }
    if ( $k eq 's') { $rx-=10.0 }
    if ( $k eq 'a') { $ry-=10.0 }
    if ( $k eq 'd') { $ry+=10.0 }
    if ( $k eq 'j') { $rz+=10.0 }
    if ( $k eq 'k') { $rz-=10.0 }
    if ( $k eq '[') { $zoom -= $zoom*0.1 }
    if ( $k eq ']') { $zoom += $zoom*0.1 }
}

sub quit
{
    glutDestroyWindow( $WinID );
    exit 0;
}

sub main
{
    glutInit();
    glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE |GLUT_DEPTH | GLUT_MULTISAMPLE );
    glutInitWindowSize($WIDTH, $HEIGHT);
    glutInitWindowPosition(100, 100);
    our $WinID = glutCreateWindow("Display");
    &init();
    glutDisplayFunc(\&display);
    glutReshapeFunc(\&reshape);
    glutKeyboardFunc(\&hitkey);
    glutIdleFunc(\&idle);
    glutMainLoop();
}

sub time_to_date
{
    my ($sec, $min, $hour, $day, $mon, $year) = localtime( shift );
    $mon += 1;
    $year += 1900;
    return sprintf "%d-%02d-%02d", $year,$mon,$day;
}


DRAW_STRING:
{
    sub draw_character
    {
        our @TEXT;
        my $char = shift;
        my $cts;
        gluTessBeginPolygon($tobj);
        for $cts ( @{$TEXT{$char}->{outline}} )
        {
            gluTessBeginContour($tobj);
            grep { gluTessVertex_p($tobj, @$_, 0.0 ) } @$cts;
            gluTessEndContour($tobj);
        }
        gluTessEndPolygon($tobj);
    }

    sub draw_string
    {
        my $s = shift;
        for my $c ( split //, $s )
        {
            draw_character($c);
            glTranslatef($TEXT{$c}->{right}, 0.0, 0.0);
        }
    }

    sub pointOnLine
    {
        my ($x1, $y1, $x2, $y2, $t) = @_;
        return (
            ($x2-$x1)*$t + $x1, 
            ($y2-$y1)*$t + $y1 
        );
    }

    sub pointOnQuadBezier
    {
        my ($x1, $y1, $x2, $y2, $x3, $y3, $t) = @_;
        return 
            pointOnLine(
                   pointOnLine( $x1, $y1, $x2, $y2, $t ),
                   pointOnLine( $x2, $y2, $x3, $y3, $t ),
                   $t
            );
    }

    sub get_contour
    {
        our $glyph;
        my $char = shift;
        #previous x, y
        my $px, $py, $parts, $step;
        my @contour = ();
        my $ncts    = -1;
        
        $parts = 5;
        $glyph = $face->glyph_from_char($char) || return undef;

        $glyph->outline_decompose(
            move_to  => 
                sub 
                {
                    ($px, $py) = @_;
                    $ncts++;
                    push @{$contour[$ncts]}, [$px, $py];
                },
            line_to  => 
                sub
                {
                    ($px, $py) = @_;
                    push @{$contour[$ncts]}, [$px, $py];
                },
            conic_to => 
                sub
                {
                    for ($step = 0.0; $step <= $parts; $step+=1.0)
                    {
                        push @{$contour[$ncts]}, 
                            [ pointOnQuadBezier( $px, $py, @_[2,3,0,1], $step/$parts ) ];
                    }
                    ($px, $py) = @_;
                },
            cubic_to => sub { warn "cubic\n"; }
        );

        return { 
            outline => [@contour],
            right   => $glyph->horizontal_advance(),
        };
    }

}