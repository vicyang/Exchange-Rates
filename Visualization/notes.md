
* ### Invalid value for shared scalar  
  使用 threads::shared 线程共享的哈希表，拷贝引用到外部  
  如果下标访问越界，提示：  
  
  `Invalid value for shared scalar`  
  
  at:  
  
  `@rates = map { $hash->{$day}{$_}[3] } @times;`  
  
  一种临时的方法是在传递引用的时候将结构体重造（参考 Data 目录）  
  
  `$$hashref = eval Dumper $hash;`  
  
  更好的方法是，在display_nearly.pl的for循环中判断是否越界  
  ```perl
  for my $di ( $begin .. $begin+10 ) {
      next if ($di < 0 or $di > $#days);
  ```
    
  同时在 $begin 加减的时候判断是否越界  
  ```perl
  if ( $k eq '-') { $begin-=1 if $begin > 0 }
  if ( $k eq '=') { $begin+=1 if $begin < $#days }
  ```
  
* ### 动画帧率不稳定问题  
  idle 函数：  
  ```perl
  $delta = time()-$t1;
  $left = $delay - $delta;
  sleep $left if $left > 0.0;
  ```
    
  总时差 渲染耗时 附加时差  
  > 0.0985 0.0001 0.0999  
  > 0.0986 0.0001 0.0999  
  > 0.0993 0.0004 0.0996  
  > 0.0990 0.0001 0.0999  
  > 0.0987 0.0001 0.0999  
  
  目标是让追加时差+渲染耗时 = 0.1秒，但实际在0.098左右  
  将 $left 保留三位小数能够得到相对准确的结果。  
  
  `$left = sprintf "%.3f", $delay - $delta;`  
  
* ### Can't use an undefined value as an ARRAY reference at Delaunay.pm line  
  display_triangulation_SpeedUp.pl  
  ```perl
  $DB_File = "../Data/2007.perldb.bin"; 
  $begin = $#days/2;  
  $tri = triangulation( $allpts->{$begin} );
  ```  
  2007-2012 的数据会有这种情况。  
  原因，采用哈希的时候，键值并不会自动转为整数，$#days为奇数的时候，  
  例如 365/2 = 182.5，由于查询不到182.5对应的值，所以提示 undefined value  
  
* ### Error:  Input must have at least three input vertices.  
  测试代码：  
  ```perl
  for my $k ( keys %$allpts  ) {
      triangulation( $allpts->{$k} );
  }
  ```
  
  原因，2007年-2012年，最后一天的数据是次年的数据，只有一项  
  > '2007.12.31' => {  
  > '00:00:07' => ['729','723.16','731.92',undef,'730.46','730.46']},  
  > '2008.01.01' => {  
  > '00:00:08' => ['729','723.16','731.92',undef,'730.46','730.46']}};  
  
  将2008年01月的数据导入 triangulation 函数的时候由于只有一项，引发错误。  

* ### 2018-01-06  
  在 ExchangeRates.pm 打开 use warnings 'all'， 提示  
  Can't locate package GLUquadricObjPtr for @OpenGL::Quad::ISA at ExchangeRates.pm line 46  
  由于 ExchangeRates 模块之内没有使用到OpenGL相关函数，暂时忽略  