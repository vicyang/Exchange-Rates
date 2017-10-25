
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

