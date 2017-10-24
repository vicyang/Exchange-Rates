use feature 'state';
use Math::Geometry::Delaunay;
use Data::Dumper;
use Data::Dump qw/dump/;
use IO::Handle;

use OpenGL qw/ :all /;
use OpenGL::Config;

STDOUT->autoflush(1);
$Data::Dumper::Indent = 1;

BEGIN
{
    our $WinID;
    our $HEIGHT = 500;
    our $WIDTH  = 700;
    our ($rx, $ry, $rz) = (0.0, 0.0, 0.0);

    # generate Delaunay triangulation
    # and Voronoi diagram for a point set
    our $point_set = [ [1,1,-5], [7,1,0], [7,3,9],
                       [3,3,0], [3,5,4], [1,5,1] ];
     
    our $tri = new Math::Geometry::Delaunay();
    $tri->addPoints($point_set);
    $tri->doEdges(1);
    $tri->doVoronoi(1);
    # called in void context
    $tri->triangulate();
    # populates the following lists

    $tri->elements(); # triangles
}

&main();

sub display
{
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glColor4f(0.8, 0.8, 0.8, 0.5);
    #glRectf(0.0, 0.0, 500.0, 500.0);
    glPushMatrix();
    glRotatef($rx, 1.0, 0.0, 0.0);
    glRotatef($ry, 0.0, 1.0, 0.0);
    glRotatef($rz, 0.0, 0.0, 1.0);

    glBegin(GL_TRIANGLES);
    $ele = $tri->elements();
    for my $a ( @$ele ) {
        for my $b ( @$a ) {
            glVertex3f( @$b[0..2] );
        }
    }
    glEnd();

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
    glPolygonMode( GL_FRONT_AND_BACK, GL_LINE );
    glEnable(GL_DEPTH_TEST);
}

sub reshape
{
    my ($w, $h) = (shift, shift);
    state $vthalf = 10.0;
    state $hzhalf = 10.0;
    state $fa = 100.0;

    glViewport(0, 0, $w, $h);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(-$vthalf, $vthalf, -$hzhalf, $hzhalf, 0.0, $fa*2.0); 
    #glFrustum(-100.0, $WIDTH-100.0, -100.0, $HEIGHT-100.0, 800.0, $fa*5.0); 
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
}

sub quit
{
    glutDestroyWindow( $WinID );
    exit 0;
}

sub main
{
    our $MAIN;

    glutInit();
    glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH_TEST | GLUT_MULTISAMPLE );
    glutInitWindowSize($WIDTH, $HEIGHT);
    glutInitWindowPosition(100, 100);
    $WinID = glutCreateWindow("SubWindow");
    
    &init();
    glutDisplayFunc(\&display);
    glutReshapeFunc(\&reshape);
    glutKeyboardFunc(\&hitkey);
    glutIdleFunc(\&idle);
    glutMainLoop();
}