=info
    外汇牌价-数据可视化
    Auth: 523066680
    Date: 2017-10
    https://github.com/vicyang/Exchange-Rates
=cut

use utf8;
use Encode;
use autodie;
use Storable;
use feature 'state';
use Font::FreeType;
use Time::HiRes qw/sleep time usleep/;
use Time::Local;
use File::Slurp;
use Data::Dumper;
use List::Util qw/sum min max/;

use IO::Handle;
use OpenGL qw/ :all /;
use OpenGL::Config;
use Math::Geometry::Delaunay;

STDOUT->autoflush(1);

BEGIN
{
    our $WinID;
    our $HEIGHT = 500;
    our $WIDTH  = 700;
    our ($rx, $ry, $rz, $zoom) = (0.0, 0.0, 0.0, 1.0);
    our ($mx, $my, $mz) = (0.0, 0.0, 0.0);

    our $DB_File = "../Data/2016.perldb.bin";
    our $hash = retrieve( $DB_File );
    our @days = (sort keys %$hash);
    #@days = @days[0..50];
    our $begin = $#days/2;                  #展示数据的起始索引
    sub col { 2 };

    our $text_mins;
    our %month;
    our %daily;
    our ($MIN, $MAX) = (1000.0, 0.0);
    my $m;     #month
    my $d;     #day
    my $last;  #last key(time) in one day
    for my $d (@days)
    {
        $this = $hash->{$d};
        $m = substr($d, 0, 7);  #年+月作为 key
        if ( not exists $month{$m} ) {
            $month{$m} = { 'min' => 1000.0, 'max' => 0.0, 'delta' => undef, 'ply' => 1.0 };
        }

        if ( not exists $daily{$d} ) {
            $daily{$d} = { 'min' => 1000.0, 'max' => 0.0, 'delta' => undef, 'ply' => 1.0 };
        }

        for my $t ( sort keys %{$hash->{$d}} )
        {
            if ($hash->{$d}{$t}[col] < $MIN) { $MIN = $hash->{$d}{$t}[col] }
            if ($hash->{$d}{$t}[col] > $MAX) { $MAX = $hash->{$d}{$t}[col] }
            if ($hash->{$d}{$t}[col] < $month{$m}->{min}) { $month{$m}->{min} = $hash->{$d}{$t}[col] }
            if ($hash->{$d}{$t}[col] > $month{$m}->{max}) { $month{$m}->{max} = $hash->{$d}{$t}[col] }
            if ($hash->{$d}{$t}[col] < $daily{$d}->{min}) { $daily{$d}->{min} = $hash->{$d}{$t}[col] }
            if ($hash->{$d}{$t}[col] > $daily{$d}->{max}) { $daily{$d}->{max} = $hash->{$d}{$t}[col] }
            $last = $t;
        }
        #如果没有22点以后的数据，按最末的数据填补
        $hash->{$d}{'23:55:00'} = $hash->{$d}{$last} if ( $last le '22:00:00');
    }

    for $m ( keys %month )
    {
        $month{$m}->{delta} = $month{$m}->{max} - $month{$m}->{min};
        $month{$m}->{ply}   = 300.0 / $month{$m}->{delta} 
            if ($month{$m}->{delta} != 0);
    }

    for $d ( keys %daily )
    {
        $daily{$d}->{delta} = $daily{$d}->{max} - $daily{$d}->{min};
        $daily{$d}->{ply}   = 300.0 / $daily{$d}->{delta} 
            if ($daily{$d}->{delta} != 0);
    }

    $DELTA = $MAX - $MIN;
    $PLY = 300.0/$DELTA;

    printf("Done.\n");
    printf("min: %.3f, max: %.3f\n", $MIN, $MAX );

    our $tobj;
    our ($font, $size) = ("C:/windows/fonts/msyh.ttf", 16);
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

    foreach $char (split //, "本当天年月日最小大高低平均值落差，：。")
    {
        $TEXT{ $char } = get_contour( $char ); 
    }
    print "Done\n";

    #创建颜色插值表
    our $table_size = 320;
    our @color_idx;
    for (0 .. $table_size) {
        push @color_idx, { 'R' => 0.0, 'G' => 0.0, 'B' => 0.0 };
    }

    fill_color( 20, 60, 1.0, 0.3, 0.3);
    fill_color(100,100, 1.0, 0.6, 0.0);
    fill_color(200,100, 0.2, 0.8, 0.2);
    fill_color(300,300, 0.2, 0.6, 1.0);

    # fill_color( 20,200, 1.0, 0.6, 0.2);
    # fill_color(150,200, 0.3, 1.0, 0.3);
    # fill_color(280,300, 0.2, 0.5, 1.0);

    print "Initial vertex pointers ... ";
    my $ta = time();
    our $allvtx;
    our $allclr;
    our $allpts;  '// Points for triangulation //';
    our $alltri;
    for $di ( 0 .. $#days )
    {
        $m = substr($days[$di], 0, 7);

        #作图
        $MIN = $month{$m}->{min};
        $MAX = $month{$m}->{max};
        $PLY = $month{$m}->{ply};
        $DELTA = $month{$m}->{delta};

        my $bright = 1.0;
        my $color;
        for my $tdi ( reverse $di .. $di+10 )
        {
            next if ( $tdi < 0 or $tdi > $#days );
            $day = $days[$tdi];
            #时间清零，避免受到上一次影响
            @times = ();
            #时间排序
            @times = sort keys %{ $hash->{$day} };

            my $t1, $x1, $y1;
            $bright = $tdi == $di ? 2.0 : 0.9*(1.0-($tdi-$di)/10.0);
            for my $ti ( 0 .. $#times )
            {
                $t1 = $times[$ti];
                $t1 =~ /^0?(\d+):0?(\d+)/;
                $x1 = ($1 * 60.0 + $2)/3.0;
                $y1 = ($hash->{$day}{$t1}[col]-$MIN)*$PLY;
                $color = $color_idx[int($y1)];
                push @{$allvtx->{$di}{$tdi}},  [$x1, $y1, -($tdi-$di)*30.0];
                push @{$allclr->{$di}{$tdi}},  [$color->{R}*$bright, $color->{G}*$bright, $color->{B}*$bright, 1.0];
                push @{$allpts->{$di}},  [$x1, -($tdi-$di)*30.0, $y1];
            }
        }
    }
    printf "Time used: %.3f\n", time() - $ta ;

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

    sub triangulation
    {
        my $points = shift;
        my $tri = new Math::Geometry::Delaunay();
        $tri->addPoints( $points );
        $tri->doEdges(1);
        $tri->doVoronoi(1);
        $tri->triangulate();
        return $tri->elements();
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
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

    glColor4f(0.8, 0.8, 0.8, 0.5);

    glPushMatrix();
    glScalef( $zoom, $zoom, $zoom );
    glRotatef($rx, 1.0, 0.0, 0.0);
    glRotatef($ry, 0.0, 1.0, 0.0);
    glRotatef($rz, 0.0, 0.0, 1.0);
    glTranslatef($mx, $my, $mz);

    '// 曲线图，allvtx 和 allclr 的key是一致的 //';
    my $obj;
    for my $k ( keys %{$allvtx->{$begin}} )
    {
        glBegin(GL_LINE_STRIP);
        $obj = $allvtx->{$begin}{$k};
        for my $i ( 0 .. $#$obj  )
        {
            glColor4f( @{$allclr->{$begin}{$k}[$i]} );
            glVertex3f( @{$obj->[$i]} );
        }
        glEnd();
    }
    
    glEnable(GL_LIGHTING);
    my $tri;
    my @tpa, @tpb, @norm;
    $tri = triangulation( $allpts->{$begin} );
    glBegin(GL_TRIANGLES);
    for my $a ( @$tri ) 
    {
        for my $i ( 0 .. 2 )
        {
            $tpa[$i] = $a->[1][$i] - $a->[0][$i] ;
            $tpb[$i] = $a->[2][$i] - $a->[0][$i] ;
        }
        normcrossprod( \@tpa, \@tpb, \@norm );
        glNormal3f( @norm );
        for my $b ( @$a ) 
        {
            $bright = 1.0 - abs($b->[1])/400.0;
            $color = $color_idx[int($b->[2])];
            glColor4f( $color->{R} * $bright, $color->{G} * $bright, $color->{B} * $bright, 0.5 );
            glVertex3f( @$b[0,2,1] );
        }
    }
    glEnd();
    glDisable(GL_LIGHTING);

    glCallList( $text_mins );
    glCallList( $begin + 1 );  #CallList 从 1 开始

    glPopMatrix();
    glutSwapBuffers();
}

sub idle 
{
    state $t1;
    state $delta;
    state $delay = 0.05;
    state $left;

    $t1 = time();

    #glutPostRedisplay();
    display();

    $delta = time()-$t1;
    $left = sprintf "%.3f", $delay - $delta;
    sleep $left if $left > 0.0;

    printf "%.4f %.4f %.4f\n", time()-$t1, $delta, $left;
}

sub init
{
    glClearColor(0.0, 0.0, 0.0, 1.0);
    #glClearColor(0.1, 0.2, 0.3, 1.0);
    glPointSize(1.0);
    glLineWidth(1.0);
    glEnable(GL_BLEND);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_POINT_SMOOTH);
    glEnable(GL_LINE_SMOOTH);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    #glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);

    glEnable(GL_LIGHTING);

    my $ambient  = OpenGL::Array->new( 4, GL_FLOAT);
    my $specular = OpenGL::Array->new( 4, GL_FLOAT);
    my $diffuse  = OpenGL::Array->new( 4, GL_FLOAT);
    my $shininess = OpenGL::Array->new( 1, GL_FLOAT);

    my $light_position = OpenGL::Array->new( 4, GL_FLOAT);
    my $light_specular = OpenGL::Array->new( 4, GL_FLOAT);
    my $light_diffuse  = OpenGL::Array->new( 4, GL_FLOAT);

    $ambient->assign(0,  ( 0.5, 0.5, 0.5, 1.0 ) );
    $specular->assign(0, ( 0.5, 0.5, 0.5, 1.0 ) );
    $diffuse->assign(0,  ( 1.0, 1.0, 1.0, 1.0 ) );
    $shininess->assign(0,  100.0 );

    $light_diffuse->assign(0, ( 1.0, 1.0, 1.0, 1.0 ) );
    $light_specular->assign(0, ( 0.2, 0.2, 0.2, 1.0 ) );
    $light_position->assign(0, ( 0.0, 1.0, 1.0, 1.0 ) );

    glMaterialfv_c(GL_FRONT_AND_BACK, GL_AMBIENT, $ambient->ptr );
    glMaterialfv_c(GL_FRONT_AND_BACK, GL_SPECULAR, $specular->ptr );
    glMaterialfv_c(GL_FRONT_AND_BACK, GL_DIFFUSE, $diffuse->ptr );
    glMaterialfv_c(GL_FRONT_AND_BACK, GL_SHININESS, $shininess->ptr );

    glLightfv_c(GL_LIGHT0, GL_POSITION, $light_position->ptr);
    glLightfv_c(GL_LIGHT0, GL_DIFFUSE, $light_diffuse->ptr);
    glLightfv_c(GL_LIGHT0, GL_SPECULAR, $light_specular->ptr);

    glEnable(GL_LIGHT0);

    glColorMaterial(GL_FRONT, GL_AMBIENT_AND_DIFFUSE);
    glEnable(GL_COLOR_MATERIAL);

    # my $light_position2 = OpenGL::Array->new( 4, GL_FLOAT);
    # my $light_specular2 = OpenGL::Array->new( 4, GL_FLOAT);
    # my $light_diffuse2  = OpenGL::Array->new( 4, GL_FLOAT);

    # $light_diffuse2->assign(0, ( 1.0, 1.0, 1.0, 1.0 ) );
    # $light_specular2->assign(0, ( 0.2, 0.2, 0.2, 1.0 ) );
    # $light_position2->assign(0, ( 0.0, 0.0, 1.0, 0.0 ) );

    # glLightfv_c(GL_LIGHT1, GL_POSITION, $light_position2->ptr);
    # glLightfv_c(GL_LIGHT1, GL_DIFFUSE, $light_diffuse2->ptr);
    # glLightfv_c(GL_LIGHT1, GL_SPECULAR, $light_specular2->ptr);
    # glEnable(GL_LIGHT1);

    $tobj = gluNewTess();
    gluTessCallback($tobj, GLU_TESS_BEGIN,     'DEFAULT');
    gluTessCallback($tobj, GLU_TESS_END,       'DEFAULT');
    gluTessCallback($tobj, GLU_TESS_VERTEX,    'DEFAULT');
    gluTessCallback($tobj, GLU_TESS_COMBINE,   'DEFAULT');
    gluTessCallback($tobj, GLU_TESS_ERROR,     'DEFAULT');
    gluTessCallback($tobj, GLU_TESS_EDGE_FLAG, 'DEFAULT');

    #CallList
    my $ta = time();
    printf "Creating display list ... ";
    my ($yy, $mm, $dd);
    my ($y, $di, $m);
    for $di ( 0 .. $#days )
    {
        glNewList ( $di+1, GL_COMPILE );
        $day = $days[$di];
        ($yy, $mm, $dd) = split(/\D/, $day );

        #标题
        glColor3f(1.0, 1.0, 1.0);
        glPushMatrix();
        glTranslatef(-80.0, 320.0, 0.0);
        draw_string(
            sprintf("%s年%s月%s日 最高:%.3f 最低:%.3f 落差: %.3f\n", 
                $yy, $mm, $dd, 
                $daily{$day}->{max}/100.0, 
                $daily{$day}->{min}/100.0, 
                $daily{$day}->{delta}/100.0
            )
        );
        glPopMatrix();

        #Y轴，按月份更新，month key = yyyy.mm
        $m = substr($days[$di], 0, 7);
        for ( $y = 0.0; $y<=300.0; $y+=15.0 )
        {
            glColor4f( @{$color_idx[int($y)]}{'R','G','B'}, 1.0 );
            glPushMatrix();
            glTranslatef(-80.0, $y, 0.0);
            glScalef(0.1, 0.1, 0.1);
            glutStrokeString(
                    GLUT_STROKE_MONO_ROMAN, 
                    sprintf "%.3f", ($month{$m}->{delta}*$y/300.0 + $MIN)/100.0 
                );
            glPopMatrix();
        }
        glEndList ();
    }
    printf "Done. Time used: %.3f\n", time()-$ta;

    $text_mins = $#days + 1 + 1;
    #横轴
    glNewList ( $text_mins, GL_COMPILE );
    glColor3f(1.0, 1.0, 1.0);
    for ( my $mins = 0.0; $mins <= 1440.0; $mins+=40.0 )
    {
        $time = sprintf "%02d:%02d", int($mins/60), $mins % 60;
        glPushMatrix();
            glTranslatef($mins/3.0, -80.0, 0.0);
            glRotatef(90.0, 0.0, 0.0, 1.0);
            glScalef(0.1, 0.08, 0.1);
            glutStrokeString(GLUT_STROKE_MONO_ROMAN, $time );
        glPopMatrix();
    }
    glEndList();


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
    if ( $k eq 'r') { ($rx, $ry, $rz) = (0.0, 0.0,0.0)  }

    if ( $k eq '-') { $begin-=1 if $begin > 0 }
    if ( $k eq '=') { $begin+=1 if $begin < $#days }

    if ( $k eq '4') { $mx-=10.0 }
    if ( $k eq '6') { $mx+=10.0 }
    if ( $k eq '8') { $my+=10.0 }
    if ( $k eq '2') { $my-=10.0 }
    if ( $k eq '5') { $mz+=10.0 }
    if ( $k eq '0') { $mz-=10.0 }

    if ( $k eq 'w') { $rx+=5.0 }
    if ( $k eq 's') { $rx-=5.0 }
    if ( $k eq 'a') { $ry-=5.0 }
    if ( $k eq 'd') { $ry+=5.0 }
    if ( $k eq 'j') { $rz+=5.0 }
    if ( $k eq 'k') { $rz-=5.0 }
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

LIGHT:
{
    sub normalize
    {
        my $v = shift;
        my $d = sqrt($v->[0]*$v->[0] + $v->[1]*$v->[1] + $v->[2]*$v->[2]);
        if ($d == 0.0)
        {
            printf("length zero!\n");
            return;
        }
        $v->[0] /= $d;
        $v->[1] /= $d;
        $v->[2] /= $d;
    }

    sub normcrossprod
    {
        my ( $v1, $v2, $out ) = @_;

        $out->[0] = $v1->[1] * $v2->[2] - $v1->[2] * $v2->[1];
        $out->[1] = $v1->[2] * $v2->[0] - $v1->[0] * $v2->[2];
        $out->[2] = $v1->[0] * $v2->[1] - $v1->[1] * $v2->[0];

        normalize( $out );
    }
}