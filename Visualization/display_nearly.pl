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
use Data::Dumper;
use List::Util qw/sum min max/;
use ExchangeRates;

use OpenGL qw/ :all /;
use OpenGL::Config;
use feature 'state';

BEGIN
{
    use DateTime;
    use IO::Handle;
    STDOUT->autoflush(1);

    our $WinID;
    our $HEIGHT = 500;
    our $WIDTH  = 700;
    our ($rx, $ry, $rz, $zoom) = (0.0, 0.0, 0.0, 1.0);
    our ($mx, $my, $mz) = (0.0, 0.0, 0.0);
    sub col { return 2 };

    our $from = DateTime->today()->add( days => -5 );
    our $to   = DateTime->today();
    our $year = $to->strftime("%Y");

    our $hash = {};
    #如果存在同年数据，先从中提取，修改在线获取的日期范围。
    if ( -e "../Data/${year}.perldb.bin")
    {
        my $history;
        $history = retrieve "../Data/${year}.perldb.bin";

        my $iter = $from->clone();
        my $date;
        while ( $iter->ymd le $to->ymd )
        {
            $date = $iter->ymd(".");
            if ( exists $history->{$date} ) 
            {
                print "$date\n";
                $hash->{$date} = $history->{$date};
            }
            else { last; }
            $iter->add( days => 1 );
        }
        $from = $iter;
    }

    our $nearly;
    ExchangeRates::main( $from->ymd(), $to->ymd(), \$nearly );
    grep { $hash->{$_} = $nearly->{$_}  } keys %$nearly;

    our @days = (sort keys %$hash);
    our $begin = 0;                  #展示数据的起始索引
    #@days = @days[10..$#days];

    our ($MIN, $MAX) = (1000.0, 0.0);
    our $PLY, $DELTA;
    
    for my $d (@days)
    {
        for my $t ( keys %{$hash->{$d}} )
        {
            if ($hash->{$d}{$t}[col] < $MIN) { $MIN = $hash->{$d}{$t}[col] }
            if ($hash->{$d}{$t}[col] > $MAX) { $MAX = $hash->{$d}{$t}[col] }
        }
    }

    $DELTA = $MAX - $MIN;
    $PLY = 300.0/$DELTA;
    printf("Done.\n");
    printf("min: %.3f, max: %.3f\n", $MIN, $MAX );

    our $tobj;
}

INIT
{
    our %TEXT;
    our ($font, $size) = ("C:/windows/fonts/msyh.ttf", 16);
    our $dpi = 100;
    our $face = Font::FreeType->new->face($font);
    $face->set_char_size($size, $size, $dpi, $dpi);

    print "Loading contours ... ";
    my $code;
    my $char;
    foreach $code (0x00..0x7F)
    {
        $char = chr( $code );
        $TEXT{ $char } = get_contour( $char ); 
    }

    foreach $char (split //, "本当天年月日最小大高低平均值落差，：。")
    {
        $TEXT{ $char } = get_contour( $char ); 
    }
    print "Done\n";

    #创建颜色插值表
    our $table_size = 360;
    our @color_idx;
    for (0 .. $table_size) {
        push @color_idx, { 'R' => 0.0, 'G' => 0.0, 'B' => 0.0 };
    }

    # fill_color( 20, 80, 0.8, 0.3, 0.3);
    # fill_color(100,100, 1.0, 0.6, 0.0);
    # fill_color(200,100, 0.2, 0.8, 0.2);
    # fill_color(300,300, 0.2, 0.6, 1.0);

    # fill_color( 0,  60, 1.0, 0.0, 0.0);
    # fill_color(60, 100, 0.0, 1.0, 0.0);
    # fill_color(120,100, 0.5, 0.0, 1.0);
    # fill_color(180,200, 0.0, 1.0, 1.0);
    # fill_color(240,300, 1.0, 0.9, 0.0);

    fill_color( 20,200, 1.0, 0.6, 0.2);
    fill_color(150,200, 0.6, 1.0, 0.6);
    fill_color(280,300, 0.3, 0.6, 1.0);

    sub fill_color 
    {
        my %insert;
        @{insert}{'offset', 'length', 'R', 'G', 'B'} = @_;
        my $site;
        my $ref;
        my $tc;

        for my $i (  -$insert{length} .. $insert{length} )
        {
            $site = $i + $insert{offset};
            next if ($site < 0 or $site > $table_size);
            $ref = $color_idx[$site];
            for my $c ('R', 'G', 'B') 
            {
                $tc = $insert{$c} - abs( $insert{$c} / $insert{length} * $i),  #等量划分 * step
                $ref->{$c} = $ref->{$c} > $tc ? $ref->{$c} : $tc  ;
            }
        }
    }
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
    state $i = 0;
    state ($min, $max, $delta, $ply);

    our ($hash, @days, $begin, $MIN, @color_idx);
    my $day;
    my $hour, $time, $last;
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

    glColor4f(0.8, 0.8, 0.8, 0.5);

    glPushMatrix();
    glScalef( $zoom, $zoom, $zoom );
    glRotatef($rx, 1.0, 0.0, 0.0);
    glRotatef($ry, 0.0, 1.0, 0.0);
    glRotatef($rz, 0.0, 0.0, 1.0);
    glTranslatef($mx, $my, $mz);
    my $bright = 1.0;

    for my $di ( $begin .. $begin+10 )
    {
        next if ($di < 0 or $di > $#days);
        $day = $days[$di];
        #时间清零，避免受到上一次影响
        @times = ();
        @rates = ();
        #时间排序
        @times = sort keys %{ $hash->{$day} };
        @rates = map { $hash->{$day}{$_}[3] } @times;

        #glColor4f(1.0, 0.5, $di/$#days, 0.8 );
        my $t1, $x1, $y1, $last_x, $last_y;
        $bright = $di == $begin ? 1.2 : 0.6*(1.0-abs($di-$begin)/10.0);
        glBegin(GL_LINE_STRIP);
        for my $ti ( 0 .. $#times )
        {
            $t1 = $times[$ti];
            $t1 =~ /^0?(\d+):0?(\d+)/;
            $x1 = ($1 * 60.0 + $2)/3.0;
            $y1 = ($hash->{$day}{$t1}[3]-$MIN)*$PLY;

            $color = $color_idx[int($y1)];
            glColor4f( $color->{R}*$bright, $color->{G}*$bright, $color->{B}*$bright, 1.0 );
            glVertex3f($x1, $y1, -($di-$begin)*30.0 );
            $last_x = $x1;
            $last_y = $y1;
        }
        glEnd();
        
        #日期
        glColor4f(1.0, 1.0, 1.0, 1.0);
        glLineWidth(1.5);
        glPushMatrix();
            glTranslatef(480.0, ($di-$begin)*20.0, -($di-$begin)*20.0 );
            #glRotatef(90.0, 0.0, 0.0, 1.0);
            glScalef(0.08, 0.12, 0.12);
            glutStrokeString(GLUT_STROKE_MONO_ROMAN, $days[$di] );
        glPopMatrix();
        glLineWidth(1.0);
    }

    glutStrokeHeight(GLUT_STROKE_MONO_ROMAN);
    glColor3f(0.6, 0.8, 1.0);

    #横轴
    for (  my $mins = 0.0; $mins <= 1440.0; $mins+=40.0 )
    {
        $time = sprintf "%02d:%02d", int($mins/60), $mins % 60;
        glPushMatrix();
            glTranslatef($mins/3.0, -80.0, 0.0);
            #glRotatef(90.0, 1.0, 0.0, 0.0);
            #glRotatef(180.0, 0.0, 1.0, 0.0);
            glRotatef(90.0, 0.0, 0.0, 1.0);
            glScalef(0.1, 0.1, 0.1);
            glutStrokeString(GLUT_STROKE_MONO_ROMAN, $time );
        glPopMatrix();
    }

    #竖轴
    for ( my $y = 0.0; $y<=300.0; $y+=15.0 )
    {
        glColor4f( @{$color_idx[int($y)]}{'R','G','B'}, 1.0 );
        glPushMatrix();
            glTranslatef(-80.0, $y, 0.0);
            glScalef(0.1, 0.1, 0.1);
            glutStrokeString(GLUT_STROKE_MONO_ROMAN, sprintf "%.3f", ( $DELTA *$y/300.0 + $MIN)/100.0 );
            #draw_string("ab:?ge数据QT");
        glPopMatrix();
    }

    #当天的数据特征
    my $min = 1000.0, $max = 0.0;
    for my $t ( keys %{$hash->{$days[$begin]}} )
    {
        if ($hash->{$days[$begin]}{$t}[col] < $min) { $min = $hash->{$days[$begin]}{$t}[col] }
        if ($hash->{$days[$begin]}{$t}[col] > $max) { $max = $hash->{$days[$begin]}{$t}[col] }
    }
    my $delta = $max - $min;
    my ($yy, $mm, $dd) = split(/\D/, $days[$begin] );
    glColor3f(1.0, 1.0, 1.0);
    glPushMatrix();
    glTranslatef(-80.0, 320.0, 0.0);
    draw_string(
        sprintf("%s年%s月%s日 最高:%.3f 最低:%.3f 落差: %.3f\n", 
            $yy, $mm, $dd, $max/100.0, $min/100.0, $delta/100.0)
    );
    glPopMatrix();

    # glPushMatrix();
    # glTranslatef(-80.0, 360.0, 0.0);
    # draw_string("Github: vicyang");
    # glPopMatrix();

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
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glPointSize(1.0);
    glLineWidth(1.0);
    glEnable(GL_BLEND);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_POINT_SMOOTH);
    glEnable(GL_LINE_SMOOTH);
    #glBlendFunc(GL_SRC_COLOR, GL_ONE_MINUS_SRC_ALPHA);
    #glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

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
    #glOrtho(-100.0, $WIDTH-100.0, -100.0, $HEIGHT-100.0, 0.0, $fa*2.0); 
    #glFrustum(-100.0, $WIDTH-100.0, -100.0, $HEIGHT-100.0, 800.0, $fa*5.0); 
    gluPerspective( 45.0, 1.0, 1.0, $fa*2.0 );
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    #gluLookAt(0.0,0.0,$fa, 0.0,0.0,0.0, 0.0,1.0, $fa);
    gluLookAt(200.0,200.0,$fa, 200.0,200.0,0.0, 0.0,1.0, $fa);
}

sub hitkey 
{
    our $WinID;
    my $k = lc(chr(shift));
    if ( $k eq 'q') { quit() }

    if ( $k eq '-' and $begin > 0     ) { $begin-=1 }
    if ( $k eq '=' and $begin < $#days) { $begin+=1 }
    # if ( $k eq '-' and ($begin > 0) ) { $begin-=1 }
    # if ( $k eq '=' and ($begin+10 < $#days) ) { $begin+=1 }

    if ( $k eq '4') { $mx-=10.0 }
    if ( $k eq '6') { $mx+=10.0 }
    if ( $k eq '8') { $my+=10.0 }
    if ( $k eq '2') { $my-=10.0 }
    if ( $k eq '5') { $mz+=10.0 }
    if ( $k eq '0') { $mz-=10.0 }

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
    our $WinID = glutCreateWindow("ExchangeRates");
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