### 获取外汇牌价历史记录  

* ### Branch Visualization  
  基于threads1.0  

* 目录结构  
  /Data 汇率数据，相关脚本  
  /Visualization 可视化程序  

* display_control.pl  
  ![](./Visualization/snap02.png)  

* display_triangulation.pl  
  ![](./Visualization/snap01.png)  

* BUG  
  2007年8月15日出现最小值为0.076的情况，原因：  
  ```perl
  '2007.08.15' => {
    '16:29:01' => ['7.57','7.51','7.6',undef,'759.21','759.21'],
  }
  ```
