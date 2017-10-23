* 2017-10-23  
  问题：storable 存储 thread::shared 标记的哈希引用，无法得到完整内容  
  临时的方案是 先用 Data::Dumper 转结构体字符串，通过 eval 获得哈希树的副本。  
  然后 store  

  其他参考  
  https://stackoverflow.com/questions/17701276/perl-using-storable-and-threadqueue-correctly  
  [Unable to store shared hash with Storable](http://www.perlmonks.org/?node_id=919696)  

  > Not much help, but I know from experimenting with shared hashes,  
  > the share method only shares the first level keys.

  其他考虑：  
  1. Clone 模块 recursively copy Perl datatypes  
  2. Storable's "dclone()" is a flexible solution for cloning variables  

  实测 clone 和 dclone 没有起到作用  