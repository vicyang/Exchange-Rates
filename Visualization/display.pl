=info
    外汇牌价-数据可视化
    Auth: 523066680
    Date: 2017-10
    https://github.com/vicyang/Exchange-Rates
=cut

no strict 'refs';
use feature "switch";  #given
use Encode;
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

    printf("loading...");
    our $hash = eval read_file( "../Data/2017.perldb" );
    our @days = (sort keys %$hash);
    our ($MIN, $MAX) = (1000.0, 0.0);
    for my $d (@days)
    {
        for my $t ( keys %{$hash->{$d}} )
        {
            if ($hash->{$d}{$t}[0] < $MIN) { $MIN = $hash->{$d}{$t}[0] }
            if ($hash->{$d}{$t}[0] > $MAX) { $MAX = $hash->{$d}{$t}[0] }
        }
    }

    printf("Done.\n");
    printf("min: %.3f, max: %.3f\n", $MIN, $MAX );
    
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
    my $hour, $time;
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glColor3f(0.8, 0.8, 0.8);
    #glRectf(0.0, 0.0, 100.0, 100.0);

    if ( $i % 2 == 0 )
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
        @rates = map { $hash->{$day}{$_}[0] } @times;
        ($min, $max) = ( min(@rates), max(@rates) );
        printf("%s, count: %d, avg: %.3f\n", $day, $#rates+1, sum(@rates)/($#rates+1) );
    }

    $i++;

    glColor3f(1.0, 0.0, 0.0);
    glBegin(GL_LINE_STRIP);
    grep 
    {
        /^(\d+):(\d+)/;
        $time = ($1.$2)/8.0 - 200.0;
        glVertex3f($time, ($hash->{$day}{$_}[0]-$MIN)*10.0 , 0.0);
        # print $hash->{$day}->{$_}->[0],"\n";
    }
    @times;

    glEnd();

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
    glLineWidth(0.5);
    glEnable(GL_BLEND);
    glEnable(GL_DEPTH_TEST);
    # glEnable(GL_POINT_SMOOTH);
    # glEnable(GL_LINE_SMOOTH);
}

sub reshape 
{
    my ($w, $h) = (shift, shift);
    my $half = 200.0;
    my $fa = 250.0;

    glViewport(0, 0, $w, $h);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    #glOrtho(-$half, $half, -$half, $half, 0.0, $fa*2.0); 
    gluPerspective( 90.0, 1.0, 1.0, $fa*2.0 );
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    gluLookAt(0.0,0.0,$fa,0.0,0.0,0.0, 0.0,1.0, $fa);
}

sub hitkey 
{
    our $WinID;
    my $k = lc(chr(shift));

    if ( $k eq 'q') { glutDestroyWindow( $WinID ) }
}

sub main 
{
    glutInit();
    glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE |GLUT_DEPTH  );
    glutInitWindowSize(500, 500);
    glutInitWindowPosition(1,1);
    our $WinID = glutCreateWindow("Display");
    &init();
    glutDisplayFunc(\&display);
    glutReshapeFunc(\&reshape);
    glutKeyboardFunc(\&hitkey);
    glutIdleFunc(\&idle);
    glutMainLoop();
}


