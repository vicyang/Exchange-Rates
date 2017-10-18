
`use v5.16;`
运行提示 strict refs
http://perldoc.perl.org/perlref.html

解决方法
no strict 'refs';

如果要开启 given 关键字，可以用
use feature "switch";

