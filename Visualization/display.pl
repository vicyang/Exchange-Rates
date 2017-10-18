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

use IO::Handle;
use OpenGL qw/ :all /;
use OpenGL::Config;
use feature 'state';

STDOUT->autoflush(1);
printf("loading...");
our $hash = eval read_file( "../Data/2015.perldb" );
our @days = (keys %$hash);
printf("Done.\n");

our $WinID;

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
    our ($hash, @days);
    my $hour;
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glColor3f(0.8, 0.8, 0.8);
    #glRectf(0.0, 0.0, 100.0, 100.0);

    if ( $i % 100 == 0 )
    {
        $day = shift @days;
        @times = keys %{ $hash->{$day} };
    }

    $i++;

    glColor3f(1.0, 0.0, 0.0);
    glBegin(GL_POINTS);
    grep 
    {
        /^(\d+)/;
        $hour = $1;
        glVertex3f($hour*10.0, ($hash->{$day}{$_}[0] - 620.0)*10.0, 0.0);
        # print $hash->{$day}->{$_}->[0],"\n";
        #print $_,"\n";
    }
    @times;

    glEnd();

    glutSwapBuffers();
}

sub idle 
{
    sleep 0.01;
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
    glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE |GLUT_DEPTH |GLUT_MULTISAMPLE );
    glutInitWindowSize(500, 500);
    glutInitWindowPosition(1,1);
    our $WinID = glutCreateWindow("bunny");
    &init();
    glutDisplayFunc(\&display);
    glutReshapeFunc(\&reshape);
    glutKeyboardFunc(\&hitkey);
    glutIdleFunc(\&idle);
    glutMainLoop();
}


