ExchangeRates.pm
使用 threads::shared 开启共享的哈希表，拷贝引用到外部
如果访问下标超出边界，提示：
`Invalid value for shared scalar`
at:
`@rates = map { $hash->{$day}{$_}[3] } @times;`

一种解决方法是在传递引用的时候将结构体重造（参考 Data 目录）
`$$hashref = eval Dumper $hash;`

以及越界的访问本来就是错误的，应在display_nearly.pl的for循环中判断是否越界
```perl
    for my $di ( $begin .. $begin+10 ) {
        next if ($di < 0 or $di > $#days);
```



